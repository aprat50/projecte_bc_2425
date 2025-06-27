#!/bin/bash

CONTRACT="erd1qqqqqqqqqqqqqpgqngg6uwmgzxwalkfjsu5y6etxlkpvs487tnfqqa9vs6" # Cambia por la dirección real del SC
PEM="./mywallet.pem"      # Cambia por la ruta a tu wallet
//PEM="./wallet.pem"
PROXY="https://devnet-api.multiversx.com"

# Función para convertir hex a decimal (maneja números grandes)erd1qqqqqqqqqqqqqpgq7kckggc68jdq7nwnvymndumqm0vngzfttnfqg5cspw
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

# Función para convertir denominación mínima a EGLD
denomination_to_egld() {
  local denomination=$1
  if [[ $denomination -eq 0 ]]; then
    echo "0 EGLD"
  else
    python3 -c "print(f'{$denomination / 10**18:.18f} EGLD')" 2>/dev/null || echo "$denomination"
  fi
}

# Función para parsear status
parse_status() {
  local status=$1
  case $status in
    ""|"00"|"0") echo "FundingPeriod (Período de financiación)" ;;
    "01"|"1") echo "Successful (Exitoso)" ;;
    "02"|"2") echo "Failed (Fallido)" ;;
    *) echo "Estado desconocido: $status" ;;
  esac
}

fund() {
  read -p "Cantidad de EGLD a donar (en denominación mínima, ej: 1000000000000000000 para 1 EGLD): " amount
  mxpy contract call $CONTRACT \
    --pem $PEM \
    --recall-nonce \
    --gas-limit=5000000 \
    --value $amount \
    --function fund \
    --proxy $PROXY \
    --chain D \
    --send
}

claim() {
  mxpy contract call $CONTRACT \
    --pem $PEM \
    --recall-nonce \
    --gas-limit=5000000 \
    --function claim \
    --proxy $PROXY \
    --chain D \
    --send
}

status() {
  echo "Consultando estado del contrato..."
  result=$(mxpy contract query $CONTRACT \
    --function status \
    --proxy $PROXY 2>/dev/null)
  
  if [[ $? -eq 0 ]]; then
    # Extraer el valor hexadecimal de la respuesta (formato: ["hex_value"])
    hex_status=$(echo "$result" | grep -o '"[^"]*"' | head -1 | tr -d '"')
    
    if [[ -n "$hex_status" && "$hex_status" != "" ]]; then
      # Convertir hex a decimal para determinar el estado
      decimal_status=$(hex_to_decimal "$hex_status")
      parsed_status=$(parse_status "$decimal_status")
      echo "Estado: $parsed_status"
    else
      parsed_status=$(parse_status "")
      echo "Estado: $parsed_status"
    fi
  else
    echo "Error al consultar el estado"
  fi
}

get_current_funds() {
  echo "Consultando fondos actuales..."
  result=$(mxpy contract query $CONTRACT \
    --function getCurrentFunds \
    --proxy $PROXY 2>/dev/null)
  
  if [[ $? -eq 0 ]]; then
    # Extraer el valor hexadecimal de la respuesta (formato: ["hex_value"])
    hex_funds=$(echo "$result" | grep -o '"[^"]*"' | head -1 | tr -d '"')
    if [[ -n "$hex_funds" && "$hex_funds" != "" ]]; then
      decimal_funds=$(hex_to_decimal "$hex_funds")
      egld_funds=$(denomination_to_egld "$decimal_funds")
      echo "Fondos actuales: $egld_funds ($decimal_funds)"
    else
      echo "Fondos actuales: 0 EGLD"
      echo "Respuesta raw: $result"
    fi
  else
    echo "Error al consultar los fondos"
  fi
}

get_target() {
  echo "Consultando meta del crowdfunding..."
  result=$(mxpy contract query $CONTRACT \
    --function getTarget \
    --proxy $PROXY 2>/dev/null)
  
  if [[ $? -eq 0 ]]; then
    # Extraer el valor hexadecimal de la respuesta (formato: ["hex_value"])
    hex_target=$(echo "$result" | grep -o '"[^"]*"' | head -1 | tr -d '"')
    if [[ -n "$hex_target" && "$hex_target" != "" ]]; then
      decimal_target=$(hex_to_decimal "$hex_target")
      egld_target=$(denomination_to_egld "$decimal_target")
      echo "Meta: $egld_target ($decimal_target)"
    else
      echo "No se pudo parsear la meta"
      echo "Respuesta raw: $result"
    fi
  else
    echo "Error al consultar la meta"
  fi
}

get_maxtarget() {
  echo "Consultando meta máxima del crowdfunding..."
  result=$(mxpy contract query $CONTRACT \
    --function getMaxTarget \
    --proxy $PROXY 2>/dev/null)
  
  if [[ $? -eq 0 ]]; then
    # Extraer el valor hexadecimal de la respuesta (formato: ["hex_value"])
    hex_target=$(echo "$result" | grep -o '"[^"]*"' | head -1 | tr -d '"')
    if [[ -n "$hex_target" && "$hex_target" != "" ]]; then
      decimal_target=$(hex_to_decimal "$hex_target")
      egld_target=$(denomination_to_egld "$decimal_target")
      echo "Meta máxima: $egld_target ($decimal_target)"
    else
      echo "No se pudo parsear la meta máxima"
      echo "Respuesta raw: $result"
    fi
  else
    echo "Error al consultar la meta máxima"
  fi
}

get_maxfund() {
  echo "Consultando límite doncaciones por donante del crowdfunding..."
  result=$(mxpy contract query $CONTRACT \
    --function getMaxFund \
    --proxy $PROXY 2>/dev/null)
  
  if [[ $? -eq 0 ]]; then
    # Extraer el valor hexadecimal de la respuesta (formato: ["hex_value"])
    hex_target=$(echo "$result" | grep -o '"[^"]*"' | head -1 | tr -d '"')
    if [[ -n "$hex_target" && "$hex_target" != "" ]]; then
      decimal_target=$(hex_to_decimal "$hex_target")
      egld_target=$(denomination_to_egld "$decimal_target")
      echo "Límite donaciones por donante : $egld_target ($decimal_target)"
    else
      echo "No se pudo parsear el límite doncaciones por donante"
      echo "Respuesta raw: $result"
    fi
  else
    echo "Error al consultar el límite doncaciones por donante"
  fi
}

get_limitfund() {
  echo "Consultando límite donación del crowdfunding..."
  result=$(mxpy contract query $CONTRACT \
    --function getLimitFund \
    --proxy $PROXY 2>/dev/null)
  
  if [[ $? -eq 0 ]]; then
    # Extraer el valor hexadecimal de la respuesta (formato: ["hex_value"])
    hex_target=$(echo "$result" | grep -o '"[^"]*"' | head -1 | tr -d '"')
    if [[ -n "$hex_target" && "$hex_target" != "" ]]; then
      decimal_target=$(hex_to_decimal "$hex_target")
      egld_target=$(denomination_to_egld "$decimal_target")
      echo "Límite máximo por donación: $egld_target ($decimal_target)"
    else
      echo "No se pudo parsear el límite donación"
      echo "Respuesta raw: $result"
    fi
  else
    echo "Error al consultar el límite donación"
  fi
}

get_deadline() {
  echo "Consultando fecha límite..."
  result=$(mxpy contract query $CONTRACT \
    --function getDeadline \
    --proxy $PROXY 2>/dev/null)
  
  if [[ $? -eq 0 ]]; then
    # Extraer el valor hexadecimal de la respuesta (formato: ["hex_value"])
    hex_deadline=$(echo "$result" | grep -o '"[^"]*"' | head -1 | tr -d '"')
    if [[ -n "$hex_deadline" && "$hex_deadline" != "" ]]; then
      decimal_deadline=$(hex_to_decimal "$hex_deadline")
      date_deadline=$(timestamp_to_date "$decimal_deadline")
      echo "Fecha límite: $date_deadline (timestamp: $decimal_deadline)"
    else
      echo "No se pudo parsear la fecha límite"
      echo "Respuesta raw: $result"
    fi
  else
    echo "Error al consultar la fecha límite"
  fi
}

get_deposit() {
  read -p "Dirección del donante: " donor
  echo "Consultando donación de $donor..."
  result=$(mxpy contract query $CONTRACT \
    --function getDeposit \
    --proxy $PROXY \
    --arguments $donor 2>/dev/null)
  
  if [[ $? -eq 0 ]]; then
    # Extraer el valor hexadecimal de la respuesta (formato: ["hex_value"])
    hex_deposit=$(echo "$result" | grep -o '"[^"]*"' | head -1 | tr -d '"')
    if [[ -n "$hex_deposit" && "$hex_deposit" != "" ]]; then
      decimal_deposit=$(hex_to_decimal "$hex_deposit")
      egld_deposit=$(denomination_to_egld "$decimal_deposit")
      echo "Donación de $donor: $egld_deposit ($decimal_deposit)"
    else
      echo "Esta dirección no ha donado nada o donación = 0 EGLD"
      echo "Respuesta raw: $result"
    fi
  else
    echo "Error al consultar la donación"
  fi
}

set_maxfunds() {
  read -p "Entrar valor límite máximo donaciones por donante: " MAX_DONATION
  if [[ $MAX_DONATION -gt 0 ]]; then
     mxpy contract call $CONTRACT \
    --pem $PEM \
    --recall-nonce \
    --gas-limit=5000000 \
    --function SetMaxFunds \
    --arguments $MAX_DONATION \
    --proxy $PROXY \
    --chain D \
    --send
  fi 
  }

set_limitfunds() {
  read -p "Entrar valor límite máximo donación: " MAX_DONATION
  if [[ $MAX_DONATION -gt 0 ]]; then
     mxpy contract call $CONTRACT \
    --pem $PEM \
    --recall-nonce \
    --gas-limit=5000000 \
    --function SetLimitFunds \
    --arguments $MAX_DONATION \
    --proxy $PROXY \
    --chain D \
    --send
  fi 
  }

set_maxtarget() {
  read -p "Entrar valor máximo meta del crowdfunding: " MAX_TARGET
  if [[ $MAX_TARGET -gt 0 ]]; then
     mxpy contract call $CONTRACT \
    --pem $PEM \
    --recall-nonce \
    --gas-limit=5000000 \
    --function SetMaxTarget \
    --arguments $MAX_TARGET \
    --proxy $PROXY \
    --chain D \
    --send
  fi 
  }

while true; do
  echo "Contracte: $CONTRACT"
  echo ""
  echo "===== Menú Crowdfunding SC ====="
  echo "1) Donar (fund)"
  echo "2) Reclamar fondos (claim)"
  echo "3) Ver estado (status)"
  echo "4) Ver fondos actuales (getCurrentFunds)"
  echo "5) Ver meta (getTarget)"
  echo "6) Ver fecha límite (getDeadline)"
  echo "7) Consultar donación de una address (getDeposit)"
  echo "8) Establecer donación máxima por donante (set_max_funds)"
  echo "9) Establecer donación máxima por donación (set_limit_funds)"
  echo "10) Establecer meta máxima (set_max_target)"
  echo "11) Consultar donación máxima por donante (getMaxFund)"
  echo "12) Consultar donación máxima por donación (getLimitFund)"
  echo "13) Consultar meta máxima (getMaxTarget)"
  echo "0) Salir"
  echo "================================"
  read -p "Elige una opción: " opcion

  case $opcion in
    1) fund ;;
    2) claim ;;
    3) status ;;
    4) get_current_funds ;;
    5) get_target ;;
    6) get_deadline ;;
    7) get_deposit ;;
    8) set_maxfunds ;;
    9) set_limitfunds ;;
    10) set_maxtarget ;;
    11) get_maxfund ;;
    12) get_limitfund ;;
    13) get_maxtarget ;;
    0) echo "¡Hasta luego!"; break ;;
    *) echo "Opción no válida." ;;
  esac
done
