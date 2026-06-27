#!/bin/zsh

# ==============================================================================
# SCRIPT MAESTRO: Creador de Instalador macOS Sequoia Offline
# Interfaz True Color de 24 bits basada en paleta personalizada.
# Optimizado para ejecución 100% externa.
# ==============================================================================

# 1. Traducción de la paleta Hexadecimal a secuencias ANSI RGB (Importada)
C_MAIN=$'\e[38;2;234;238;244m'     # #EAEEF4
C_SEC=$'\e[38;2;167;183;207m'      # #A7B7CF
C_HL1=$'\e[38;2;255;255;184m'      # #FFFFB8
C_HL2=$'\e[38;2;204;178;68m'       # #CCB244
C_ACC1=$'\e[38;2;222;221;250m'     # #DEDDFA
C_ACC2=$'\e[38;2;166;164;215m'     # #A6A4D7
C_FRAME1=$'\e[38;2;99;98;124m'     # #63627C
C_FRAME2=$'\e[38;2;72;81;153m'     # #485199
C_ERR=$'\e[38;2;171;22;17m'        # #AB1611
C_SUCC=$'\e[38;2;146;194;29m'      # #92C21D
C_RESET=$'\e[0m'

# Interfaz visual inicial
echo "${C_FRAME2}========================================================${C_RESET}"
echo "${C_HL1}       CREADOR DE INSTALADOR MACOS SEQUOIA OFFLINE      ${C_RESET}"
echo "${C_FRAME2}========================================================${C_RESET}"
echo ""
echo "${C_MAIN}Arrastra aquí el disco de trabajo (donde se descargará el PKG)${C_RESET}"
echo "${C_SEC}(Ejemplo: /Volumes/tokyo doll):${C_RESET}"
echo -n "${C_HL2}> ${C_RESET}"
read -r EXT_VOL

# Limpieza absoluta de la ruta
EXT_VOL="${(Q)EXT_VOL}"
EXT_VOL="${EXT_VOL%"${EXT_VOL##*[![:space:]]}"}"

if [[ ! -d "$EXT_VOL" ]]; then
    echo "\n${C_ERR}[ERROR] No se encontró el volumen '$EXT_VOL'. Verifica que esté conectado.${C_RESET}"
    exit 1
fi

# Definición de Rutas
WORK_DIR="$EXT_VOL/instalador - macOS Sequoia"
PKG_PATH="$WORK_DIR/InstallAssistant.pkg"
APP_PATH="$EXT_VOL/Applications/Install macOS Sequoia.app"
INSTRUCTIONS_PATH="$WORK_DIR/INSTRUCCIONES_POST_REINICIO.txt"
APPLE_SUS_URL="https://swcdn.apple.com/content/downloads/43/58/082-16524-A_VHRNGIT194/ksdv19dcxx90ja7nronzpb4kr4val0imsz/InstallAssistant.pkg"

echo "\n${C_ACC1}Verificando espacio en el disco de trabajo...${C_RESET}"
DEVICE_ID=$(diskutil info "$EXT_VOL" | awk '/Device Node:/ {print $3}')
FREE_BYTES=$(diskutil info -plist "$DEVICE_ID" | plutil -extract FreeSpace raw -o - - 2>/dev/null)

# Se necesitan aprox 30GB libres (14GB PKG + 15GB App) si el PKG no existe
REQUIRED_BYTES=30000000000
if [[ ! -f "$PKG_PATH" && ! -d "$APP_PATH" ]]; then
    if (( FREE_BYTES < REQUIRED_BYTES )); then
        echo "\n${C_ERR}[ERROR] El disco de trabajo necesita al menos 30 GB libres para descargar y extraer el instalador.${C_RESET}"
        echo "${C_ERR}Actualmente solo tienes $((FREE_BYTES / 1000000000)) GB libres en $EXT_VOL.${C_RESET}"
        exit 1
    fi
fi

echo "${C_SUCC}✓${C_MAIN} Creando directorio de trabajo en: ${C_HL1}$WORK_DIR${C_RESET}"
mkdir -p "$WORK_DIR"

# 3. Descarga Directa
echo "\n${C_FRAME1}========================================================${C_RESET}"
echo "${C_HL1} FASE 1: Descarga al Disco Externo${C_RESET}"
echo "${C_FRAME1}========================================================${C_RESET}"
if [[ -f "$PKG_PATH" ]]; then
    echo "${C_SUCC}✓${C_MAIN} El archivo InstallAssistant.pkg ya existe. Omitiendo descarga.${C_RESET}"
else
    echo "${C_MAIN}Descargando macOS Sequoia (~14 GB). Esto tomará tiempo...${C_RESET}"
    curl -L -C - -o "$PKG_PATH" "$APPLE_SUS_URL"
    if [[ $? -ne 0 ]]; then
        echo "\n${C_ERR}[ERROR] Hubo un problema al descargar el paquete. Inténtalo nuevamente.${C_RESET}"
        exit 1
    fi
fi

# 4. Extracción
echo "\n${C_FRAME1}========================================================${C_RESET}"
echo "${C_HL1} FASE 2: Extracción del Instalador${C_RESET}"
echo "${C_FRAME1}========================================================${C_RESET}"
if [[ -d "$APP_PATH" ]]; then
    echo "${C_SUCC}✓${C_MAIN} La app instaladora ya se encuentra extraída en el disco externo.${C_RESET}"
else
    echo "${C_MAIN}Extrayendo el paquete. ${C_ERR}Se pedirán permisos de administrador...${C_RESET}"
    sudo installer -pkg "$PKG_PATH" -target "$EXT_VOL"
    if [[ $? -eq 0 ]]; then
        echo "${C_SUCC}✓${C_MAIN} Extracción completada.${C_RESET}"
        echo "${C_SEC}Eliminando el PKG para liberar espacio...${C_RESET}"
        rm -f "$PKG_PATH"
    else
        echo "\n${C_ERR}[ERROR] Hubo un problema al extraer el instalador.${C_RESET}"
        exit 1
    fi
fi

# 5. Creación del Medio Booteable
echo "\n${C_FRAME1}========================================================${C_RESET}"
echo "${C_HL1} FASE 3: Flasheo del Medio de Instalación${C_RESET}"
echo "${C_FRAME1}========================================================${C_RESET}"
echo "${C_ERR}¡ATENCIÓN! Necesitas indicar la ruta de la partición/pendrive que se BORRARÁ.${C_RESET}"
echo "${C_SEC}(Ejemplo: /Volumes/Instalador). NO ingreses la raíz del disco de trabajo.${C_RESET}"
echo "${C_MAIN}Aquí tienes tus volúmenes externos conectados:${C_RESET}"
diskutil list external

echo -n "\n${C_HL2}Ingresa la RUTA EXACTA del volumen a formatear (por defecto: /Volumes/Instalador): ${C_RESET}"
read TARGET_USB

if [[ -z "$TARGET_USB" ]]; then
    TARGET_USB="/Volumes/Instalador"
fi

# Limpieza de la ruta del target
TARGET_USB="${(Q)TARGET_USB}"
TARGET_USB="${TARGET_USB%"${TARGET_USB##*[![:space:]]}"}"

if [[ ! -d "$TARGET_USB" ]]; then
    echo "\n${C_ERR}[ERROR] No se encontró la ruta $TARGET_USB. Abortando flasheo.${C_RESET}"
    exit 1
fi

if [[ "$TARGET_USB" == "$EXT_VOL" || "$TARGET_USB" == "$EXT_VOL/" ]]; then
    echo "\n${C_ERR}[ERROR] ¡Estás intentando formatear el mismo disco de trabajo! Abortando por seguridad.${C_RESET}"
    exit 1
fi

echo "\n${C_MAIN}Iniciando proceso de flasheo. Confirma con la tecla ${C_SUCC}'Y'${C_MAIN} cuando la herramienta te lo pida...${C_RESET}"
sudo "$APP_PATH/Contents/Resources/createinstallmedia" --volume "$TARGET_USB"

# 6. Generación del Pre-Script / Instrucciones
echo "\n${C_FRAME1}========================================================${C_RESET}"
echo "${C_HL1} FASE 4: Generación de Instrucciones Post-Reinicio${C_RESET}"
echo "${C_FRAME1}========================================================${C_RESET}"
cat << 'EOF' > "$INSTRUCTIONS_PATH"
--- GUÍA DE REINICIO: CHIP M2 ---

Debido a la arquitectura Secure Boot del M2, el equipo no puede automatizar
un reinicio directo hacia un puerto USB. Debes seguir estos pasos manuales:

1. Apaga el equipo por completo (no reiniciar, apagar).
2. Mantén presionado el botón de encendido (Touch ID) sin soltarlo.
3. Suelta el botón cuando aparezca en pantalla "Cargando opciones de arranque".
4. Verás tu disco interno y el instalador de macOS Sequoia.
5. Selecciona el volumen de Sequoia.
6. [Opcional pero recomendado] Si quieres una instalación limpia porque no tienes espacio:
   - Abre "Utilidad de Discos".
   - Selecciona tu disco interno (generalmente Macintosh HD).
   - Haz clic en "Borrar" (Asegúrate de usar formato APFS).
   - Cierra Utilidad de Discos.
7. Haz clic en "Instalar macOS Sequoia" y sigue el asistente.

Nota: El instalador (.app) sigue en tu disco externo en la carpeta Applications.
Si la instalación finaliza, puedes borrarlo para liberar espacio.
EOF

echo "\n${C_SUCC}¡Proceso automatizado completado con éxito!${C_RESET}"
echo "${C_MAIN}Las instrucciones de reinicio se guardaron en: ${C_HL1}$INSTRUCTIONS_PATH${C_RESET}"
