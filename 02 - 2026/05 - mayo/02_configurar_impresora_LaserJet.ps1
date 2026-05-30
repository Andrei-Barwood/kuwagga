# =============================================================================
# Herramienta Universal HP - Instalacion y Solucion PCL XL (Version ASCII)
# =============================================================================

# ---> CAMBIA ESTE VALOR <---
# Puede ser una IP exacta (ej. "192.168.2.48") o una subred (ej. "192.168.2")
$Objetivo = "192.168.2.48"

# =============================================================================

$DriverHP = "HP Universal Printing PS"
$DriverFallback = "Microsoft PS Class Driver"

# Logica para detectar si pusiste una IP unica o una subred
if ($Objetivo -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
    $ListaIPs = @($Objetivo)
    Write-Host "[-] Modo: Direccion IP Unica ($Objetivo)" -ForegroundColor Cyan
} elseif ($Objetivo -match "^\d{1,3}\.\d{1,3}\.\d{1,3}$") {
    $ListaIPs = 1..254 | ForEach-Object { "$Objetivo.$_" }
    Write-Host "[-] Modo: Escaneo de Subred ($Objetivo.x)" -ForegroundColor Cyan
} else {
    Write-Host "[ERROR] Formato incorrecto. Usa '192.168.2.48' o '192.168.2'." -ForegroundColor Red
    exit
}

Write-Host "Iniciando proceso..." -ForegroundColor Cyan

foreach ($IP in $ListaIPs) {
    # Prueba rapida al puerto de impresion
    $Conexion = Test-NetConnection -ComputerName $IP -Port 9100 -InformationLevel Quiet -WarningAction SilentlyContinue
    
    if ($Conexion) {
        Write-Host "[+] Impresora detectada en IP: $IP" -ForegroundColor Yellow
        
        $NombrePuerto = "IP_$IP"
        $NombreImpresora = "HP LaserJet ($IP)"

        # Crear puerto si no existe
        if (-not (Get-PrinterPort -Name $NombrePuerto -ErrorAction SilentlyContinue)) {
            Add-PrinterPort -Name $NombrePuerto -PrinterHostAddress $IP
        }

        # Intentar instalar con el driver PS de HP, sino usar el generico de Windows
        try {
            Add-Printer -Name $NombreImpresora -DriverName $DriverHP -PortName $NombrePuerto -ErrorAction Stop
            Write-Host "    [OK] Blindada con exito usando controlador HP Universal PS." -ForegroundColor Green
        } catch {
            try {
                Add-Printer -Name $NombreImpresora -DriverName $DriverFallback -PortName $NombrePuerto -ErrorAction Stop
                Write-Host "    [OK] Blindada con exito usando controlador Microsoft PS (Fallback)." -ForegroundColor Green
            } catch {
                Write-Host "    [ERROR] Fallo la instalacion. Faltan controladores en este Windows." -ForegroundColor Red
            }
        }
    }
}

Write-Host "[-] Reiniciando cola de impresion para aplicar cambios..." -ForegroundColor Cyan
Restart-Service -Name Spooler -Force
Write-Host "[OK] Herramienta finalizada." -ForegroundColor Green