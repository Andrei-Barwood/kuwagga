Write-Host "Buscando instalación de Hitman: Codename 47..." -ForegroundColor Cyan

# Rutas comunes de instalación en Windows (GOG o Steam)
$possiblePaths = @(
    "C:\GOG Games\Hitman Codename 47",
    "C:\Program Files (x86)\GOG Galaxy\Games\Hitman Codename 47",
    "C:\Program Files (x86)\Steam\steamapps\common\Hitman Codename 47"
)

$gameDir = $null
foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $gameDir = $path
        break
    }
}

if (-not $gameDir) {
    Write-Host "❌ No se encontró la instalación de Hitman Codename 47 en las rutas por defecto." -ForegroundColor Red
    Pause
    exit
}

$iniPath = Join-Path $gameDir "Hitman.ini"

if (-not (Test-Path $iniPath)) {
    Write-Host "❌ No se encontró Hitman.ini en $gameDir" -ForegroundColor Red
    Pause
    exit
}

Write-Host "✅ Juego encontrado en $gameDir. Aplicando parche de pantalla negra..." -ForegroundColor Green

# Arreglar Hitman.ini sin afectar los controles
$iniContent = Get-Content $iniPath -Raw
$iniContent = $iniContent -replace "(?m)^Resolution\s+.*", "Resolution 1280x720`r`nWindow"
Set-Content -Path $iniPath -Value $iniContent

Write-Host "🎉 ¡Parche visual aplicado! Ya puedes usar tu app de mapeo para los controles." -ForegroundColor Cyan
Pause
