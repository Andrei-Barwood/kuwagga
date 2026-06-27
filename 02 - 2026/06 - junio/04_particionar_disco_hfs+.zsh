#!/bin/zsh

# ==============================================================================
# ASISTENTE AUTOMATIZADO DE REDIMENSIONAMIENTO (HFS+)
# Interfaz True Color de 24 bits basada en paleta personalizada.
# ==============================================================================

# 1. Traducción de la paleta Hexadecimal a secuencias ANSI RGB
C_MAIN=$'\e[38;2;234;238;244m'     # #EAEEF4 (Texto principal)
C_SEC=$'\e[38;2;167;183;207m'      # #A7B7CF (Texto secundario)
C_HL1=$'\e[38;2;255;255;184m'      # #FFFFB8 (Resaltado claro / Rutas)
C_HL2=$'\e[38;2;204;178;68m'       # #CCB244 (Resaltado oscuro / Tamaños)
C_ACC1=$'\e[38;2;222;221;250m'     # #DEDDFA (Acentos sutiles)
C_ACC2=$'\e[38;2;166;164;215m'     # #A6A4D7 (Acentos intermedios)
C_FRAME1=$'\e[38;2;99;98;124m'     # #63627C (Líneas divisorias suaves)
C_FRAME2=$'\e[38;2;72;81;153m'     # #485199 (Líneas y marcos fuertes)
C_ERR=$'\e[38;2;171;22;17m'        # #AB1611 (Errores y alertas)
C_SUCC=$'\e[38;2;146;194;29m'      # #92C21D (Éxito y confirmación)
C_RESET=$'\e[0m'                   # Resetear formato

# 2. Interfaz visual inicial
echo "${C_FRAME2}========================================================${C_RESET}"
echo "${C_HL1}       ASISTENTE INTELIGENTE DE PARTICIONES (HFS+)      ${C_RESET}"
echo "${C_FRAME2}========================================================${C_RESET}"
echo ""
echo "${C_MAIN}Arrastra tu disco aquí desde el Finder o escribe la ruta${C_RESET}"
echo "${C_SEC}(Ejemplo: /Volumes/tokyo doll):${C_RESET}"
echo -n "${C_HL2}> ${C_RESET}"
read -r TARGET_PATH

# 3. Limpieza absoluta de la ruta (comillas, espacios invisibles y escapes)
TARGET_PATH="${(Q)TARGET_PATH}"
TARGET_PATH="${TARGET_PATH%"${TARGET_PATH##*[![:space:]]}"}"

if [[ ! -d "$TARGET_PATH" ]]; then
    echo "\n${C_ERR}[ERROR] No se encontró la ruta. Verifica que el disco esté conectado.${C_RESET}"
    exit 1
fi

# 4. Extraer el nodo físico del dispositivo a nivel de kernel
DEVICE_ID=$(diskutil info "$TARGET_PATH" | awk '/Device Node:/ {print $3}')

if [[ -z "$DEVICE_ID" ]]; then
    echo "\n${C_ERR}[ERROR] No se pudo determinar el nodo del dispositivo.${C_RESET}"
    exit 1
fi

# Validar que sea un volumen HFS/HFS+
FS_TYPE=$(diskutil info -plist "$DEVICE_ID" | plutil -extract FilesystemType raw -o - - 2>/dev/null)

if [[ "$FS_TYPE" != *"hfs"* ]]; then
    echo "\n${C_ERR}[ERROR] El disco no es HFS+ (tipo detectado: '$FS_TYPE'). Este script solo soporta particiones HFS+.${C_RESET}"
    exit 1
fi

echo "\n${C_ACC1}Analizando tu disco de forma automática...${C_RESET}"

# 5. Interrogar al sistema operativo por los bytes exactos y espacio libre
CURRENT_BYTES=$(diskutil info -plist "$DEVICE_ID" | plutil -extract TotalSize raw -o - - 2>/dev/null)
CURRENT_FREE_BYTES=$(diskutil info -plist "$DEVICE_ID" | plutil -extract FreeSpace raw -o - - 2>/dev/null)

if [[ -z "$CURRENT_BYTES" || ! "$CURRENT_BYTES" =~ ^[0-9]+$ || -z "$CURRENT_FREE_BYTES" ]]; then
    echo "\n${C_ERR}[ERROR] No se pudo leer el tamaño actual o el espacio libre de tu disco.${C_RESET}"
    exit 1
fi

CURRENT_USED_BYTES=$((CURRENT_BYTES - CURRENT_FREE_BYTES))

# --- EL CEREBRO DEL SCRIPT ---
# 20 GB exactos restados matemáticamente en segundo plano.
TWENTY_GB_BYTES=20000000000
# Se requieren 50 GB libres en total (20 GB para la partición, 30 GB para descargas del script 05)
FIFTY_GB_BYTES=50000000000

if (( CURRENT_FREE_BYTES < FIFTY_GB_BYTES )); then
    echo "\n${C_ERR}[ERROR] Tu disco no tiene 50 GB de ESPACIO LIBRE. Solo tienes $((CURRENT_FREE_BYTES / 1000000000)) GB libres.${C_RESET}"
    echo "${C_ERR}Necesitas 20 GB para el instalador y 30 GB adicionales para descargar los archivos de macOS.${C_RESET}"
    exit 1
fi

NEW_BYTES=$((CURRENT_BYTES - TWENTY_GB_BYTES))

# Conversión a Gigabytes para mostrarle al humano
CURRENT_GB=$((CURRENT_BYTES / 1000000000))
USED_GB=$((CURRENT_USED_BYTES / 1000000000))
FREE_GB=$((CURRENT_FREE_BYTES / 1000000000))
NEW_GB=$((NEW_BYTES / 1000000000))

if (( NEW_BYTES < 0 )); then
    echo "\n${C_ERR}[ERROR] Tu disco es demasiado pequeño (menor a 20 GB). No se puede continuar.${C_RESET}"
    exit 1
fi

# 6. El menú amigable y sofisticado
echo "${C_FRAME1}--------------------------------------------------------${C_RESET}"
echo "${C_SUCC}✓${C_MAIN} Disco detectado:     ${C_HL1}$TARGET_PATH${C_SEC} ($DEVICE_ID)${C_RESET}"
echo "${C_SUCC}✓${C_MAIN} Tamaño total:        ${C_HL1}$CURRENT_GB GB${C_RESET}"
echo "${C_SUCC}✓${C_MAIN} Espacio en uso:      ${C_HL2}$USED_GB GB${C_MAIN} (Tus datos actuales)${C_RESET}"
echo "${C_SUCC}✓${C_MAIN} Espacio libre:       ${C_HL1}$FREE_GB GB${C_RESET}"
echo "${C_FRAME1}--------------------------------------------------------${C_RESET}"
echo "${C_MAIN} Acción automatizada: Se extraerán ${C_HL2}20 GB exactos${C_MAIN} del espacio libre.${C_RESET}"
echo "${C_MAIN} Tamaño final:        Tu partición principal quedará de ${C_HL1}$NEW_GB GB${C_RESET}"
echo "${C_SEC}                      (Tus $USED_GB GB de datos caben perfectamente y están a salvo)${C_RESET}"
echo "${C_FRAME1}--------------------------------------------------------${C_RESET}"

echo "\n${C_MAIN}Todo está calculado. ¿Deseas aplicar los cambios ahora?${C_RESET}"
echo "${C_SEC}Presiona ${C_SUCC}ENTER${C_SEC} para continuar o ${C_ERR}CTRL+C${C_SEC} para cancelar.${C_RESET}"
read

echo "\n${C_ACC2}Trabajando... (Esto puede tomar unos segundos. No desconectes el disco)${C_RESET}\n"

# 7. Ejecución maestra.
TARGET_SIZE_B="${NEW_BYTES}B"
diskutil resizeVolume "$DEVICE_ID" "$TARGET_SIZE_B" JHFS+ "Instalador" 0b

echo "\n${C_FRAME2}========================================================${C_RESET}"
echo "${C_SUCC} ¡LISTO! Proceso finalizado con éxito.${C_RESET}"
echo "${C_MAIN} Tu nueva partición te espera en: ${C_HL1}/Volumes/Instalador${C_RESET}"
echo "${C_FRAME2}========================================================${C_RESET}"
