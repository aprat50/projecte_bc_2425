#!/bin/bash

#DESPLEGAMENT FET AMB 
# mxpy contract deploy 
#      --bytecode ./output/asset-loan.wasm   
#      --recall-nonce   
#      --proxy=https://devnet-gateway.multiversx.com   
#      --chain D   
#      --gas-limit=40000000   
#      --pem=./wallets/mainwallet.pem   
#      --arguments addr:erd19dwqnvn2lcw35kagrehe3axqatdth0j48z8hsjgzs6kwsa9esu3q5884gh addr:erd1uwqln3hkre8x0mnzr5agq7ruvav9e237atxjnzlps7nzvyh9tnfqyqtelc    
#      --arguments addr:erd1pzx4tcnhcgp050965lmc03pg8s3300xzw3kmzja3gjmzxk499mwqqdazpp   
#      --send

CONTRACT="erd1qqqqqqqqqqqqqpgqjyynsdhq4yx8jx6unhf505j2h2nqmfs9xt6ssvz5t7" # ORIGINAL
PEM="./wallets/admwallet.pem"       # Wallet usuari administrador
#PEM="./wallets/prowallet.pem"       # Wallet professor
#PEM="./wallets/aluwallet.pem"        # Wallet alumne
#PEM="./wallets/mainwallet.pem"      # Wallet contracte
PROXY="https://devnet-api.multiversx.com"

# Funció para convertir hex a decimal (maneja números grandes)
hex_to_decimal() {
  local hex_value=$1
  if [[ $hex_value == "0x"* ]]; then
    hex_value=${hex_value#0x}
  fi
  if [[ -z "$hex_value" || "$hex_value" == "00" || "$hex_value" == "" ]]; then
    echo "0"
  else
    # Usar python para manejar números grandes
    python3 -c "print(int('$hex_value', 16))" 2>/dev/null || echo "0"
  fi
}

hex_to_str()
{
  local hex_value=$1
  if [[ $hex_value == "0x"* ]]; then
    hex_value=${hex_value#0x}
  fi
  if [[ -z "$hex_value" || "$hex_value" == "00" || "$hex_value" == "" ]]; then
    echo ""
  else
    # Usar python para manejar números grandes
    python3 -c "print(bytes.fromhex($hex_value).decode('utf-8'))" 2>/dev/null || echo ""
  fi

}
# Funció para convertir timestamp a fecha formato dd/MM/yy hh:mm:ss
timestamp_to_date() {
  local timestamp=$1
  if [[ $timestamp -eq 0 ]]; then
    echo "No definido"
  else
    # Intentar con sintaxis de macOS/BSD primero, luego con Linux
    date -r "$timestamp" "+%d/%m/%y %H:%M:%S" 2>/dev/null || \
    date -d "@$timestamp" "+%d/%m/%y %H:%M:%S" 2>/dev/null || \
    echo "Fecha inválida"
  fi
}

# Funció per a parsejar status 
# adaptar a l'status els assets
parse_status() {
  local status=$1
  local discriminant=$(echo $status | jq '.__discriminant__')
  case $discriminant in
    ""|"00"|"0") echo "Disponible" ;;
    "01"|"1") echo "Cancelat (baixa)" ;;
    "02"|"2") echo "En préstec" ;;
    "03"|"3") echo "En reparació" ;;
    *) echo "Estat desconegut: $status" ;;
  esac
}

parse_address()
{
  local address=$1
  if [[ -z $address ]] then
    echo ""
  else
    echo $(mxpy wallet bech32 --encode $address)
  fi
}

query_transaction_info() {
  tx_hash=$1

  if [[ -z "$tx_hash" ]]; then
    echo ""
  fi

  response=$(curl -s "$PROXY/transactions/$tx_hash")
  if [[ -z "$response" || "$response" == "null" ]]; then
    echo ""
  else
    echo "$response" | jq
  fi
}

transaction_validation()
{   
    # Validar que la transacció s'ha completat correctament
    if [[ -s ./logs/transaction.json ]]; then
       output=$(cat ./logs/transaction.json)
       info=$(query_transaction_info $(echo "$output" | jq -r '.emittedTransactionHash'))
       if [[ -z $info ]] then
         echo ""
       else
         transstatus=$(echo "$info" | jq -r '.status')

         if [[ "$transstatus" == "fail" ]] then
            echo "Transacció fallida"
            transerrm=$(echo $(echo "$(echo "$info" | jq -r '.operations')" | jq -r '.[]') | jq -r '.message')
            echo "Missatge: $transerrm"
         else 
            echo $1
         fi
       fi

    else
      output=""
    fi
}

# Funció per mostrar els actius de forma llegible
display_asset() {
  local asset_json=$1
  local code=$(hex_to_str $(echo $asset_json | jq '.code'))
  local name=$(hex_to_str $(echo "$asset_json" | jq '.name'))
  local location=$(hex_to_str $(echo "$asset_json" | jq '.location'))
  local status_hex=$(echo "$asset_json" | jq '.status')
  local owner=$(echo "$asset_json" | jq -r '.owner')
  local borrower=$(echo "$asset_json" | jq -r '.borrower')
  local loan_end=$(echo "$asset_json" | jq -r '.loan_end_timestamp')

  echo "Codi: $code"
  echo "Nom: $name"
  echo "Ubicació: $location"
  echo "Estat: $(parse_status "$status_hex")"
  echo "Propietari: $(parse_address $owner)"
   
  #echo "Propietari: " $(parse_address "0x$owner")
  if [ "$borrower" != "null" ]; then
    echo "Prestatari: $(parse_address $borrower)"
    if [ "$loan_end" != "null" ]; then
      echo "Fi del préstec: $(timestamp_to_date "$loan_end")"
    fi
  fi
  echo "----------------------------------------"
}

# Registrar nou actiu
register_asset() {
  echo "=== Registrar nou actiu ==="
  read -p "Codi de l'actiu: " code
  read -p "Nom de l'actiu: " name
  read -p "Ubicació de l'actiu: " location

  # Convert inputs to hex strings for the contract call
  hex_code=$(echo -n "$code" | xxd -p)
  hex_name=$(echo -n "$name" | xxd -p)
  hex_location=$(echo -n "$location" | xxd -p)

  echo "Registrant actiu..."
  mxpy contract call $CONTRACT \
    --pem $PEM \
    --recall-nonce \
    --gas-limit=4000000 \
    --function "registerAsset" \
    --arguments "0x$hex_code" "0x$hex_name" "0x$hex_location" \
    --proxy $PROXY \
    --chain D \
    --send \
    --outfile "./logs/transaction.json" \
    --wait-result

  if [[ $? -eq 0 ]]; then
    transaction_validation "Actiu registrat correctament"
  else
    echo "Error al registrar l'actiu"
  fi
}

change_asset_status() {
  echo "=== Canviar estat d'un actiu ==="
  read -p "Codi de l'actiu: " code
  
  echo "Estats disponibles:"
  echo "0) Disponible"
  echo "1) Cancel·lat (baixa)"
  echo "2) En préstec"
  echo "3) En reparació"
  read -p "Selecciona el nou estat (0-3): " status_option

  # # Convert status option to enum value
  # case $status_option in
  #   0) status="Available" ;;
  #   1) status="Cancel" ;;
  #   2) status="Loan" ;;
  #   3) status="Repair" ;;
  #   *) echo "Opció no vàlida"; return 1 ;;
  # esac

  # Convert inputs to hex strings
  hex_code=$(echo -n "$code" | xxd -p)
  # hex_status=$(echo -n "$status_option" | xxd -p)

  echo "Canviant estat de l'actiu..."
  mxpy contract call $CONTRACT \
    --pem $PEM \
    --recall-nonce \
    --gas-limit=4000000 \
    --function "changeAssetStatus" \
    --arguments "0x$hex_code" $status_option \
    --proxy $PROXY \
    --chain D \
    --send \
    --outfile "./logs/transaction.json" \
    --wait-result

  if [[ $? -eq 0 ]]; then
    transaction_validation "L'estat de l'actiu s'ha canviat correctament"
  else
    echo "Error al canviar l'estat de l'actiu"

  fi
}

register_loan() {
  # s'ha d'executar des del wallet del prestatari
  echo "=== Registrar préstec d'actiu ==="
  read -p "Codi de l'actiu: " code
  #read -p "Adreça del prestatari: " borrower
  read -p "Duració del préstec (en dies): " days

  # Convert days to seconds for the contract
  duration=$((days * 24 * 60 * 60))

  # Convert inputs to hex strings
  hex_code=$(echo -n "$code" | xxd -p)

  echo "Registrant préstec..."
  mxpy contract call $CONTRACT \
    --pem $PEM \
    --recall-nonce \
    --gas-limit=4000000 \
    --function "registerLoan" \
    --arguments "0x$hex_code" $duration \
    --proxy $PROXY \
    --chain D \
    --send \
    --outfile "./logs/transaction.json" \
    --wait-result 

  if [[ $? -eq 0 ]]; then
   transaction_validation "Préstec registrat correctament"
  else
    echo "Error al registrar el préstec"
  fi
}

return_asset() {
  #S'ha d'executar des del wallet del prestatari
  echo "=== Retornar actiu prestat ==="
  read -p "Codi de l'actiu: " code

  # Convert input to hex string
  hex_code=$(echo -n "$code" | xxd -p)

  echo "Retornant actiu..."
  mxpy contract call $CONTRACT \
    --pem $PEM \
    --recall-nonce \
    --gas-limit=4000000 \
    --function "returnAsset" \
    --arguments "0x$hex_code" \
    --proxy $PROXY \
    --chain D \
    --send \
    --outfile "./logs/transaction.json" \
    --wait-result

  if [[ $? -eq 0 ]]; then
    transaction_validation "Actiu retornat correctament"
  else
    echo "Error al retornar l'actiu"
    echo "Nota: Només el prestatari actual pot retornar l'actiu"
  fi
}

add_to_whitelist() {
  echo "=== Afegir adreça a la llista blanca ==="
  read -p "Introdueix l'adreça a afegir: " address

  if [[ -z "$address" ]]; then
    echo "Adreça buida. Operació cancel·lada."
    return 1
  fi

  echo "Afegint $address a la whitelist..."
  mxpy contract call $CONTRACT \
    --pem $PEM \
    --recall-nonce \
    --gas-limit=3000000 \
    --function "addToWhitelist" \
    --arguments "addr:$address" \
    --proxy $PROXY \
    --chain D \
    --send \
    --outfile "./logs/transaction.json" \
    --wait-result

  if [[ $? -eq 0 ]]; then
    transaction_validation "L'adreça s'ha afegit amb èxit"
  else
    echo "Error en afegir l'adreça a la whitelist."
  fi
}

remove_from_whitelist() {
  echo "=== Eliminar adreça de la llista blanca ==="
  read -p "Introdueix l'adreça a eliminar: " address

  if [[ -z "$address" ]]; then
    echo "Adreça buida. Operació cancel·lada."
    return 1
  fi

  echo "Eliminant $address de la whitelist..."
  mxpy contract call $CONTRACT \
    --pem $PEM \
    --recall-nonce \
    --gas-limit=3000000 \
    --function "removeFromWhitelist" \
    --arguments "addr:$address" \
    --proxy $PROXY \
    --chain D \
    --send \
    --outfile "./logs/transaction.json" \
    --wait-result

  if [[ $? -eq 0 ]]; then
    transaction_validation "L'adreça s'ha eliminat amb èxit"
  else
    echo "Error en eliminar l'adreça de la whitelist."
  fi
}

add_to_admin_whitelist() {
  echo "=== Afegir adreça a la admin whitelist ==="
  read -p "Introdueix l'adreça a afegir: " address

  if [[ -z "$address" ]]; then
    echo "Adreça buida. Operació cancel·lada."
    return 1
  fi

  echo "Afegint $address a la admin whitelist..."
  mxpy contract call $CONTRACT \
    --pem $PEM \
    --recall-nonce \
    --gas-limit=3000000 \
    --function "addToAdminWhitelist" \
    --arguments "addr:$address" \
    --proxy $PROXY \
    --chain D \
    --send \
    --outfile "./logs/transaction.json" \
    --wait-result

  if [[ $? -eq 0 ]]; then
    transaction_validation "L'adreça s'ha afegit amb èxit"
  else
    echo "Error en afegir l'adreça a la admin whitelist."
  fi
}

remove_from_admin_whitelist() {
  echo "=== Eliminar adreça de la admin whitelist ==="
  read -p "Introdueix l'adreça a eliminar: " address

  if [[ -z "$address" ]]; then
    echo "Adreça buida. Operació cancel·lada."
    return 1
  fi

  echo "Eliminant $address de la admin whitelist..."
  mxpy contract call $CONTRACT \
    --pem $PEM \
    --recall-nonce \
    --gas-limit=3000000 \
    --function "removeFromAdminWhitelist" \
    --arguments "addr:$address" \
    --proxy $PROXY \
    --chain D \
    --send \
    --outfile "./logs/transaction.json" \
    --wait-result

  if [[ $? -eq 0 ]]; then
    transaction_validation "L'adreça s'ha eliminat amb èxit"
  else
    echo "Error en eliminar l'adreça de la admin whitelist."
  fi
}

get_admin_whitelist() {
  echo "=== Llista admin whitelist actual ==="

  result=$(mxpy contract query $CONTRACT \
    --function "getAdminWhitelist" \
    --proxy $PROXY 2>/dev/null)

  if [[ $? -eq 0 ]]; then
    if [[ $(echo "$result" | jq 'length') -eq 0 ]]; then
      echo "La admin whitelist està buida."
    else
      echo "Adreces a la admin whitelist:"
      echo "$result" | jq -r '.[]' | while read -r addr; do
        echo $(parse_address $addr)
      done
    fi
  else
    echo "Error al consultar la admin whitelist."
  fi
}



get_asset() {

  # Convert input to hex string
  hex_code=$(echo -n "$1" | xxd -p)
  
  result=$(mxpy contract query $CONTRACT \
    --function "getAsset" \
    --arguments "0x$hex_code" \
    --abi ./output/asset-loan.abi.json \
    --proxy $PROXY 2>/dev/null)
  
  if [[ $? -eq 0 ]]; then
    if [[ $(echo "$result" | jq '. | length') -eq 0 ]]; then
      echo "Actiu no trobat"
    else
      display_asset $(echo "$result" | jq -c '.[]' )
    fi
  else
    echo "Error al consultar l'actiu"
  fi
}

get_owner_assets() {
  echo "=== Consultar actius d'un propietari ==="
  read -p "Adreça del propietari: " owner_address
  
  result=$(mxpy contract query $CONTRACT \
    --function "getOwnerAssets" \
    --arguments "addr:"$owner_address \
    --proxy $PROXY 2>/dev/null)
  
  if [[ $? -eq 0 ]]; then
    if [[ $(echo "$result" | jq '. | length') -eq 0 ]]; then
      echo "Aquest propietari no té cap actiu registrat"
    else
      echo "Actius trobats:"
      echo "$result" | jq -c '.[]' | while read -r asset_code; do
        str_asset_code=$(hex_to_str $asset_code)
        get_asset $str_asset_code
      done
    fi
  else
    echo "Error al consultar els actius del propietari"
  fi
}

get_whitelist() {
  echo "=== Llista blanca actual ==="

  result=$(mxpy contract query $CONTRACT \
    --function "getWhitelist" \
    --proxy $PROXY 2>/dev/null)

  if [[ $? -eq 0 ]]; then
    if [[ $(echo "$result" | jq 'length') -eq 0 ]]; then
      echo "La llista blanca està buida."
    else
      echo "Adreces a la whitelist:"
      echo "$result" | jq -r '.[]' | while read -r addr; do
        echo $(parse_address $addr)
      done
    fi
  else
    echo "Error al consultar la llista blanca."
  fi
}

while true; do
  echo "Contracte: $CONTRACT"
  echo ""
  echo "===== Menú Préstec d'actius ====="
  echo "1) Registrar actiu (registerAsset)"
  echo "2) Canviar estat actiu (changeAssetStatus)"
  echo "3) Registrar préstec (registerLoan)"
  echo "4) Retornar actiu (returnAsset)"
  echo "5) Veure actiu (getAsset)"
  echo "6) Veure actius d'un propietari (getOwnerAssets)"
  echo "------------------------------------------------"
  echo "7) Afegir a la llista blanca (addToWhitelist)"
  echo "8) Eliminar de la llista blanca (removeFromWhitelist)"
  echo "9) Veure llista blanca (getWhitelist)"
  echo "------------------------------------------------"
  echo "10) Afegir a la admin whitelist (addToAdminWhitelist)"
  echo "11) Eliminar de la admin whitelist (removeFromAdminWhitelist)"
  echo "12) Veure admin whitelist (getAdminWhitelist)"
  echo "------------------------------------------------"
  echo "13) Consultar informació de transacció (queryTransactionInfo)"
  echo "------------------------------------------------"
  echo "0) Sortir"
  echo "================================================="
  read -p "Tria una opció: " opcio
  

  case $opcio
   in
    1) register_asset ;;
    2) change_asset_status ;;
    3) register_loan ;;
    4) return_asset ;;
    5) echo "=== Consultar actiu ==="
       read -p "Codi de l'actiu: " code
       get_asset $code
       ;;
    6) get_owner_assets ;;
    7) add_to_whitelist ;;
    8) remove_from_whitelist ;;
    9) get_whitelist ;;
    10) add_to_admin_whitelist ;;
    11) remove_from_admin_whitelist ;;
    12) get_admin_whitelist ;;
    13) query_transaction_info ;;
    0) echo "¡Fins aviat!"; break ;;
    *) echo "Opció no vàlida." ;;
  esac
done
