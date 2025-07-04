#!/bin/bash

# Uso: ./extraer_ascii.sh <cadena_hexadecimal>
# Ejemplo: ./extraer_ascii.sh 0000004039663932376230303964323838663363663063333062396634323334333138366538623439326263343733343832363032373131376262306233316464643032

if [ $# -eq 1 ]; then
    DATA="$1"
else
    echo "Pega la cadena devuelta por listar_certificados:"
    read DATA
fi

DATA=$(echo "$DATA" | tr -d '"[:space:]')

while [ -n "$DATA" ]; do
    LEN_HEX=${DATA:0:8}
    LEN_DEC=$((16#$LEN_HEX))
    HASH_HEX=${DATA:8:$((LEN_DEC*2))}
    # Convierte de hexadecimal a texto ASCII y lo muestra
    echo -n "$HASH_HEX" | xxd -r -p
    echo    # Salto de línea
    DATA=${DATA:$((8+LEN_DEC*2))}
done
