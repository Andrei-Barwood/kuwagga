<#
.SYNOPSIS
    Script de restauracion de red nivel profundo con branding visual (ANSI True Color).
.DESCRIPTION
    Ejecuta 9 pasos de reparacion logica con barra de progreso, output en vivo y paleta personalizada.
#>

# Comprobacion de privilegios de Administrador
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Este script necesita ejecutarse como Administrador."
    Pause
    exit
}

# -----------------------------------------------------------------------------
# MOTOR DE RENDERIZADO ANSI (PALETA DE BRANDING GITHUB)
# -----------------------------------------------------------------------------
function Get-Ansi {
    param([string]$Hex)
    $Hex = $Hex.Replace('#', '')
    $R = [convert]::ToInt32($Hex.Substring(0,2), 16)
    $G = [convert]::ToInt32($Hex.Substring(2,2), 16)
    $B = [convert]::ToInt32($Hex.Substring(4,2), 16)
    return "$([char]27)[38;2;$R;$G;$B`m"
}

# Definicion de la paleta
$C_A7B7CF = Get-Ansi "#A7B7CF" # Azul-Gris claro (Listas y variables)
$C_485199 = Get-Ansi "#485199" # Azul profundo (Bordes estructurales)
$C_63627C = Get-Ansi "#63627C" # Purpura-Gris opaco (Para el Tail/Leak de fondo)
$C_C2C0E3 = Get-Ansi "#C2C0E3" # Lavanda suave (Textos de exito y confirmaciones)
$C_FFFF99 = Get-Ansi "#FFFF99" # Amarillo palido (Advertencias y nombres de error)
$C_EBF8FF = Get-Ansi "#EBF8FF" # Hielo brillante (Titulos principales)
$C_EAEEF4 = Get-Ansi "#EAEEF4" # Gris-Azulado muy claro (Texto general)
$Reset    = "$([char]27)[0m"   # Resetea el color al estado original de la terminal

Clear-Host
Write-Host "${C_485199}===============================================================================${Reset}"
Write-Host "${C_EBF8FF}               PROTOCOLO DE RESCATE DE RED - GUIA DE SINTOMAS                  ${Reset}"
Write-Host "${C_485199}===============================================================================${Reset}"
Write-Host "${C_EAEEF4} 1. Fallo DHCP (APIPA):      ${C_FFFF99}Dice 'Sin internet', IP es 169.254.x.x.${Reset}"
Write-Host "${C_EAEEF4} 2. Stack TCP/IP Corrupto:   ${C_FFFF99}IP valida, pero no logra enrutar trafico.${Reset}"
Write-Host "${C_EAEEF4} 3. Catalogo Winsock Roto:   ${C_FFFF99}Navegadores no abren web, pero hay ping.${Reset}"
Write-Host "${C_EAEEF4} 4. Cache DNS Envenenada:    ${C_FFFF99}Error 'DNS_PROBE_FINISHED_NXDOMAIN'.${Reset}"
Write-Host "${C_EAEEF4} 5. Cache ARP Atascada:      ${C_FFFF99}No detecta el switch tras cambio fisico.${Reset}"
Write-Host "${C_EAEEF4} 6. Proxy Residual:          ${C_FFFF99}Salida bloqueada por servidor proxy fantasma.${Reset}"
Write-Host "${C_EAEEF4} 7. IP Estatica Erronea:     ${C_FFFF99}Alguien dejo una IP manual fuera de rango.${Reset}"
Write-Host "${C_EAEEF4} 8. Stack IPv6 Corrupto:     ${C_FFFF99}Fallos inesperados en servicios modernos.${Reset}"
Write-Host "${C_EAEEF4} 9. Firewall Bloqueado:      ${C_FFFF99}Politicas alteradas que impiden salida.${Reset}"
Write-Host "${C_485199}===============================================================================${Reset}"
Write-Host ""
Write-Host "${C_A7B7CF}Presiona ENTER para iniciar la limpieza profunda de red, o CTRL+C para cancelar.${Reset}"
Read-Host

Write-Host ""
Write-Host "${C_EBF8FF}INICIANDO SECUENCIA DE REPARACION...${Reset}"
Write-Host ""

# -----------------------------------------------------------------------------
# MOTOR DE EJECUCION
# -----------------------------------------------------------------------------
function Ejecutar-Paso {
    param (
        [int]$Id,
        [int]$Total,
        [string]$Mensaje,
        [scriptblock]$Comando
    )

    $Porcentaje = [math]::Round(($Id / $Total) * 100)
    
    Write-Progress -Activity "Reparando Adaptadores de Red" -Status "Paso $Id de $($Total): $Mensaje" -PercentComplete $Porcentaje

    # Imprimimos el paso usando la paleta base (EAEEF4) sin salto de linea
    Write-Host "${C_EAEEF4}[*] $Mensaje...${Reset}" -NoNewline

    try {
        $Salida = & $Comando 2>&1
        # Exito en Lavanda suave (C2C0E3)
        Write-Host " ${C_C2C0E3}[OK]${Reset}"

        $LineasValidas = $Salida | Where-Object { $_ -match '\S' }
        if ($LineasValidas.Count -gt 0) {
            $Tail = $LineasValidas | Select-Object -Last 3
            foreach ($Linea in $Tail) {
                # El Tail/Leak en Purpura-Gris opaco (63627C)
                Write-Host "${C_63627C}    > $Linea${Reset}"
            }
        } else {
             Write-Host "${C_63627C}    > (Proceso completado silenciosamente)${Reset}"
        }

    } catch {
        # Fallos en Amarillo palido (FFFF99)
        Write-Host " ${C_FFFF99}[FALLO MENOR]${Reset}"
        Write-Host "${C_63627C}    > Error capturado: $_${Reset}"
    }

    Start-Sleep -Milliseconds 600
}

# -----------------------------------------------------------------------------
# DICCIONARIO DE TAREAS
# -----------------------------------------------------------------------------
$Tareas = @(
    @{ Msj = "Liberando concesion IPv4 actual"; Cmd = { ipconfig /release } }
    @{ Msj = "Renovando concesion IPv4 via DHCP"; Cmd = { ipconfig /renew } }
    @{ Msj = "Restableciendo el Stack TCP/IPv4"; Cmd = { netsh int ip reset } }
    @{ Msj = "Restableciendo el catalogo Winsock"; Cmd = { netsh winsock reset } }
    @{ Msj = "Vaciando cache DNS local"; Cmd = { ipconfig /flushdns } }
    @{ Msj = "Forzando registro de DNS"; Cmd = { ipconfig /registerdns } }
    @{ Msj = "Borrando tabla de enrutamiento ARP"; Cmd = { arp -d * } }
    @{ Msj = "Desactivando Proxy residuales"; Cmd = { Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -name ProxyEnable -Value 0 -ErrorAction Stop } }
    @{ Msj = "Asegurando interfaces en modo DHCP"; Cmd = { 
        Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceAlias -match "Ethernet|Wi-Fi" } | Set-NetIPInterface -Dhcp Enabled
        Get-DnsClientServerAddress -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceAlias -match "Ethernet|Wi-Fi" } | Set-DnsClientServerAddress -ResetServerAddresses
    } }
    @{ Msj = "Restableciendo el Stack TCP/IPv6"; Cmd = { netsh int ipv6 reset } }
    @{ Msj = "Restaurando reglas de Windows Firewall"; Cmd = { netsh advfirewall reset } }
)

$TotalPasos = $Tareas.Count
$Contador = 1

foreach ($Tarea in $Tareas) {
    Ejecutar-Paso -Id $Contador -Total $TotalPasos -Mensaje $Tarea.Msj -Comando $Tarea.Cmd
    $Contador++
}

Write-Progress -Activity "Reparando Adaptadores de Red" -Completed

Write-Host ""
Write-Host "${C_485199}===============================================================================${Reset}"
Write-Host "${C_EBF8FF} PROTOCOLO COMPLETADO.                                                         ${Reset}"
Write-Host "${C_485199}===============================================================================${Reset}"
Write-Host "${C_FFFF99}NOTA: REINICIA el equipo para aplicar la reconstruccion de Winsock.${Reset}"
Write-Host ""

Read-Host "${C_A7B7CF}Presiona ENTER para salir...${Reset}"