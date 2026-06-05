<#
.SYNOPSIS
    Instalador desatendido de Python para Windows.
.DESCRIPTION
    Descarga, instala silenciosamente y configura el PATH para Python.
#>

# 1. Comprobacion estricta de privilegios de Administrador
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "ERROR: Debes ejecutar este script como Administrador."
    Write-Host "Haz clic derecho en el archivo .ps1 y selecciona 'Ejecutar con PowerShell'." -ForegroundColor Yellow
    Pause
    exit
}

Clear-Host
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "      INSTALADOR AUTOMATICO DE PYTHON    " -ForegroundColor White
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 2. Descargar el instalador oficial
Write-Host "[*] Descargando Python 3.12.4 (64-bits)..." -NoNewline
Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe" -OutFile "python_installer.exe"
Write-Host " [OK]" -ForegroundColor Green

# 3. Instalar de forma silenciosa
Write-Host "[*] Instalando silenciosamente y configurando PATH (espera unos segundos)..." -NoNewline
Start-Process -FilePath ".\python_installer.exe" -ArgumentList "/quiet PrependPath=1" -Wait
Write-Host " [OK]" -ForegroundColor Green

# 4. Limpieza: Borrar el instalador descargado
Write-Host "[*] Limpiando archivos temporales..." -NoNewline
Remove-Item ".\python_installer.exe" -Force
Write-Host " [OK]" -ForegroundColor Green

# 5. Refrescar la variable PATH en la consola actual
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " INSTALACION COMPLETADA EXITOSAMENTE.    " -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Version instalada: " -ForegroundColor Yellow -NoNewline
python --version
Write-Host ""

Read-Host "Presiona ENTER para salir..."