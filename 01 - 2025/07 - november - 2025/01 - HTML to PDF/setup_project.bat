@echo off
REM ============================================================================
REM setup_project.bat - Script de configuración automática para Windows
REM ============================================================================
REM Uso: Doble-click o ejecutar desde PowerShell
REM Este script configura todo el proyecto automáticamente en Windows

setlocal enabledelayedexpansion

REM Colores (simulados con títulos)
title HTML to PDF Converter - Setup Automatico

echo.
echo ============================================================
echo  HTML to PDF Converter - Setup Automatico
echo  Configuracion completa del proyecto
echo ============================================================
echo.

REM ============================================================================
REM Paso 1: Verificar requisitos del sistema
REM ============================================================================
echo [1/10] Verificando requisitos del sistema...

python --version >nul 2>&1
if errorlevel 1 (
    echo X ERROR: Python no esta instalado
    echo   Descargalo desde: https://www.python.org/
    pause
    exit /b 1
)
for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo OK Python encontrado: %PYTHON_VERSION%

pip --version >nul 2>&1
if errorlevel 1 (
    echo X ERROR: pip no esta instalado
    pause
    exit /b 1
)
echo OK pip encontrado

echo.

REM ============================================================================
REM Paso 2: Crear estructura de directorios
REM ============================================================================
echo [2/10] Creando estructura de directorios...

if not exist scripts mkdir scripts
if not exist data mkdir data
if not exist output mkdir output
if not exist logs mkdir logs

echo OK Directorios creados

echo.

REM ============================================================================
REM Paso 3: Crear entorno virtual
REM ============================================================================
echo [3/10] Creando entorno virtual...

if exist venv (
    echo   Entorno virtual ya existe
    set /p RECREATE="   Deseas recrearlo? (s/n): "
    if /i "%RECREATE%"=="s" (
        rmdir /s /q venv
        python -m venv venv
        echo OK Entorno virtual recreado
    )
) else (
    python -m venv venv
    echo OK Entorno virtual creado
)

echo.

REM ============================================================================
REM Paso 4: Activar entorno virtual
REM ============================================================================
echo [4/10] Activando entorno virtual...

call venv\Scripts\activate.bat
echo OK Entorno virtual activado

echo.

REM ============================================================================
REM Paso 5: Actualizar pip y setuptools
REM ============================================================================
echo [5/10] Actualizando pip y setuptools...

python -m pip install --upgrade pip setuptools wheel >nul 2>&1
echo OK pip, setuptools y wheel actualizados

echo.

REM ============================================================================
REM Paso 6: Instalar requisitos de Python
REM ============================================================================
echo [6/10] Instalando requisitos de Python...

if exist requirements.txt (
    pip install -r requirements.txt
    echo OK Requisitos instalados
) else (
    echo   requirements.txt no encontrado
    echo   Instalando WeasyPrint manualmente...
    pip install weasyprint==61.0 requests lxml python-dotenv Pillow fonttools
    echo OK Dependencias instaladas
)

echo.

REM ============================================================================
REM Paso 7: Verificar instalacion
REM ============================================================================
echo [7/10] Verificando instalacion...

python -c "from weasyprint import HTML, CSS; print('OK')" >nul 2>&1
if errorlevel 1 (
    echo X ERROR: WeasyPrint no se instalo correctamente
    echo   Intenta: pip install --force-reinstall weasyprint
    pause
    exit /b 1
)
echo OK WeasyPrint instalado correctamente

echo.

REM ============================================================================
REM Paso 8: Crear archivo .env
REM ============================================================================
echo [8/10] Creando archivo de configuracion...

if not exist .env (
    (
        echo # Configuracion del proyecto HTML to PDF
        echo # Estos valores pueden ser modificados segun necesidad
        echo.
        echo # Formato del PDF (A4, Letter, etc.)
        echo PDF_FORMAT=A4
        echo.
        echo # Margenes en milimetros
        echo MARGIN_TOP=15
        echo MARGIN_BOTTOM=15
        echo MARGIN_LEFT=15
        echo MARGIN_RIGHT=15
        echo.
        echo # Inyeccion automatica de CSS para control de saltos
        echo INJECT_PAGE_BREAK_CSS=true
        echo.
        echo # Archivo de log
        echo LOG_FILE=conversion.log
        echo.
        echo # Zoom del PDF (1.0 = 100%)
        echo PDF_ZOOM=1.0
        echo.
        echo # Presentational hints (true/false)
        echo PRESENTATIONAL_HINTS=true
    ) > .env
    echo OK .env creado
) else (
    echo   .env ya existe
)

echo.

REM ============================================================================
REM Paso 9: Crear script de lanzamiento rapido
REM ============================================================================
echo [9/10] Creando script de lanzamiento rapido...

if not exist run_conversion.bat (
    (
        echo @echo off
        echo call venv\Scripts\activate.bat
        echo.
        echo if "%%1"=="" (
        echo     echo Uso: run_conversion.bat archivo.html [salida.pdf]
        echo     exit /b 1
        echo )
        echo.
        echo set INPUT=%%1
        echo set OUTPUT=output\%%~n1.pdf
        echo if not "%%2"=="" set OUTPUT=%%2
        echo.
        echo python html_to_pdf_converter.py "data\!INPUT!" -o "!OUTPUT!"
    ) > run_conversion.bat
    echo OK Script de lanzamiento creado
)

echo.

REM ============================================================================
REM Paso 10: Mostrar instrucciones finales
REM ============================================================================
echo [10/10] Completando setup...

echo.
echo ============================================================
echo  OK SETUP COMPLETADO EXITOSAMENTE
echo ============================================================
echo.

echo PROXIMOS PASOS:
echo.
echo 1. Copiar tu archivo HTML a la carpeta 'data\':
echo    - Tu archivo debe estar en: data\tu_archivo.html
echo.
echo 2. Copiar el script a 'scripts\':
echo    - html_to_pdf_converter.py debe estar en: scripts\
echo.
echo 3. Ejecutar conversion (abrir terminal en esta carpeta):
echo    - Opcion A: python html_to_pdf_converter.py data\tu_archivo.html
echo    - Opcion B: run_conversion.bat tu_archivo.html
echo.
echo 4. El PDF se creara en:
echo    - output\tu_archivo.pdf
echo.

echo DOCUMENTACION:
echo  - Lectura rapida: GUIA_RAPIDA.md
echo  - Tutorial completo: TUTORIAL_COMPLETO.md
echo  - Calculos de tablas: CALCULOS_DIMENSIONAMIENTO.md
echo  - Resumen ejecutivo: RESUMEN_EJECUTIVO.md
echo.

echo OK Listo! Puedes empezar a convertir tus archivos HTML a PDF
echo.

pause
