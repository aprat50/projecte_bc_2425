#!/bin/bash

#DESPLEGAMENT FET AMB 

# mxpy contract deploy --bytecode ./output/asset-loan.wasm \
# --proxy=https://devnet-gateway.multiversx.com \
# --recall-nonce \
# --arguments addr:erd1pzx4tcnhcgp050965lmc03pg8s3300xzw3kmzja3gjmzxk499mwqqdazpp addr:erd1uwqln3hkre8x0mnzr5agq7ruvav9e237atxjnzlps7nzvyh9tnfqyqtelc
# --gas-limit 20000000 \
# --pem=wallet.pem \
# --send

CONTRACT="erd1qqqqqqqqqqqqqpgqf45wwxnc7pan4uakfakgcqyp2j0axjht9mwq0p5cs0" # Cambia por la dirección real del SC
#PEM="./wallets/wallet.pem"      # Cambia por la ruta a tu wallet
PEM="./wallets/prowallet.pem"  
#PEM="./wallets/aluwallet.pem"  
PROXY="https://devnet-api.multiversx.com"

# Función para convertir hex a decimal (maneja números grandes)
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
# Función para convertir timestamp a fecha formato dd/MM/yy hh:mm:ss
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
  case $status in
    ""|"00"|"0") echo "Disponible" ;;
    "01"|"1") echo "Cancelat (baixa)" ;;
    "02"|"2") echo "En préstec" ;;
    "03"|"3") echo "En reparació" ;;
    *) echo "Estat desconegut: $status" ;;
  esac
}


# status() {
#   echo "Consultando estado del contrato..."
#   result=$(mxpy contract query $CONTRACT \
#     --function status \
#     --proxy $PROXY 2>/dev/null)
  
#   if [[ $? -eq 0 ]]; then
#     # Extraer el valor hexadecimal de la respuesta (formato: ["hex_value"])
#     hex_status=$(echo "$result" | grep -o '"[^"]*"' | head -1 | tr -d '"')
    
#     if [[ -n "$hex_status" && "$hex_status" != "" ]]; then
#       # Convertir hex a decimal para determinar el estado
#       decimal_status=$(hex_to_decimal "$hex_status")
#       parsed_status=$(parse_status "$decimal_status")
#       echo "Estado: $parsed_status"
#     else
#       parsed_status=$(parse_status "")
#       echo "Estado: $parsed_status"
#     fi
#   else
#     echo "Error al consultar el estado"
#   fi
# }

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
    --gas-limit=5000000 \
    --function "registerAsset" \
    --arguments "0x$hex_code" "0x$hex_name" "0x$hex_location" \
    --proxy $PROXY \
    --chain D \
    --send

  if [[ $? -eq 0 ]]; then
    echo "Actiu registrat correctament"
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
    --gas-limit=5000000 \
    --function "changeAssetStatus" \
    --arguments "0x$hex_code" $status_option \
    --proxy $PROXY \
    --chain D \
    --send

  if [[ $? -eq 0 ]]; then
    echo "Estat de l'actiu canviat correctament"
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
    --gas-limit=5000000 \
    --function "registerLoan" \
    --arguments "0x$hex_code" $duration \
    --proxy $PROXY \
    --chain D \
    --send

  if [[ $? -eq 0 ]]; then
    echo "Préstec registrat correctament"
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
    --gas-limit=5000000 \
    --function "returnAsset" \
    --arguments "0x$hex_code" \
    --proxy $PROXY \
    --chain D \
    --send

  if [[ $? -eq 0 ]]; then
    echo "Actiu retornat correctament"
  else
    echo "Error al retornar l'actiu"
    echo "Nota: Només el prestatari actual pot retornar l'actiu"
  fi
}

# Funció per mostrar els actius de forma llegible
display_asset() {
  local asset_json=$1
  local code=$(echo "$asset_json" | jq -r '.code')
  local name=$(echo "$asset_json" | jq -r '.name')
  local location=$(echo "$asset_json" | jq -r '.location')
  local status_hex=$(echo "$asset_json" | jq -r '.status')
  local owner=$(echo "$asset_json" | jq -r '.owner')
  local borrower=$(echo "$asset_json" | jq -r '.borrower')
  local loan_end=$(echo "$asset_json" | jq -r '.loan_end_timestamp')

  echo "Codi: $code"
  echo "Nom: $name"
  echo "Ubicació: $location"
  echo "Estat: $(parse_status "$status_hex")"
  echo "Propietari: $owner"
  if [ "$borrower" != "null" ]; then
    echo "Prestatari: $borrower"
    if [ "$loan_end" != "null" ]; then
      echo "Fi del préstec: $(timestamp_to_date "$loan_end")"
    fi
  fi
  echo "----------------------------------------"
}

get_my_assets() {
  echo "=== Els meus actius ==="
  
  result=$(mxpy contract query $CONTRACT \
    --function "getMyAssets" \
    --proxy $PROXY 2>/dev/null)
  
  if [[ $? -eq 0 ]]; then
    if [[ $(echo "$result" | jq '. | length') -eq 0 ]]; then
      echo "No tens cap actiu registrat"
    else
      echo "$result" | jq -c '.[]' | while read -r asset; do
        display_asset "$asset"
      done
    fi
  else
    echo "Error al consultar els actius"
  fi
}

get_asset() {

  # Convert input to hex string
  hex_code=$(echo -n "$1" | xxd -p)
  
  result=$(mxpy contract query $CONTRACT \
    --function "getAsset" \
    --arguments "0x$hex_code" \
    --proxy $PROXY 2>/dev/null)
  
  if [[ $? -eq 0 ]]; then
    if [[ $(echo "$result" | jq '. | length') -eq 0 ]]; then
      echo "Actiu no trobat"
    else
      echo "$result"
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

while true; do
  echo "Contracte: $CONTRACT"
  echo ""
  echo "===== Menú Préstec d'actius ====="
  echo "1) Registrar actiu (registerAsset)"
  echo "2) Canviar estat actiu (changeAssetStatus)"
  echo "3) Registrar préstec (registerLoan)"
  echo "4) Retornar actiu (returnAsset)"
  echo "5) Veure actius propis (getMyAssets)"
  echo "6) Veure actiu (getAsset)"
  echo "7) Veure actius d'un propietari (getOwnerAssets)"
  echo "0) Sortir"
  echo "================================"
  read -p "Tria una opció: " opcio
  

  case $opcio
   in
    1) register_asset ;;
    2) change_asset_status ;;
    3) register_loan ;;
    4) return_asset ;;
    5) get_my_assets ;;
    6) echo "=== Consultar actiu ==="
       read -p "Codi de l'actiu: " code
       get_asset $code
       ;;
    7) get_owner_assets ;;
    0) echo "¡Fins aviat!"; break ;;
    *) echo "Opció no vàlida." ;;
  esac
done
