function Obtener-RutasAutoCAD {
    $rutas = @()
    $autodeskPath = "HKCU:\Software\Autodesk"
    
    if (Test-Path $autodeskPath) {
        # Busca dinamicamente cualquier clave base que contenga la palabra "AutoCAD"
        $carpetasBase = Get-ChildItem -Path $autodeskPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match "AutoCAD" }
        
        foreach ($base in $carpetasBase) {
            # Entra a la version (ej. R24.0)
            $versiones = Get-ChildItem -Path $base.PSPath -ErrorAction SilentlyContinue
            foreach ($version in $versiones) {
                # Entra al perfil especifico (ej. ACAD-4101:409)
                $perfiles = Get-ChildItem -Path $version.PSPath -ErrorAction SilentlyContinue
                foreach ($perfil in $perfiles) {
                    $rutas += $perfil
                }
            }
        }
    }
    return $rutas
}

function Mostrar-Informacion {
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "   INFORMACION DEL SCRIPT (DETECCION DINAMICA)"
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "Este script gestiona la visibilidad del 'InfoCenter' en AutoCAD."
    Write-Host "El InfoCenter es la barra superior derecha que contiene el boton de"
    Write-Host "inicio y cierre de sesion de la cuenta de Autodesk."
    Write-Host ""
    Write-Host "Mecanismo tecnico:"
    Write-Host "1. Busca dinamicamente en HKCU:\Software\Autodesk cualquier"
    Write-Host "   instalacion que coincida con 'AutoCAD' (incluyendo LT, Architecture)."
    Write-Host "2. Entra a cada version y perfil encontrado."
    Write-Host "3. Modifica la clave DWORD llamada 'InfoCenterOn':"
    Write-Host "   - Valor 0: Oculta el InfoCenter (Impide cerrar sesion)."
    Write-Host "   - Valor 1: Muestra el InfoCenter (Permite cerrar sesion)."
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "Presiona cualquier tecla para volver al menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Simulacion-Prueba {
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host "   PASADA DE PRUEBA (DRY RUN) - NO SE HARAN CAMBIOS"
    Write-Host "==========================================================" -ForegroundColor Yellow
    
    $perfilesAutoCAD = Obtener-RutasAutoCAD
    
    if ($perfilesAutoCAD.Count -gt 0) {
        Write-Host "Escaneo dinamico completado. Instalaciones encontradas:" -ForegroundColor Cyan
        foreach ($perfil in $perfilesAutoCAD) {
            $infoCenterPath = "$($perfil.PSPath)\InfoCenter"
            Write-Host "[SIMULACION] Detectado: $($perfil.PSChildName)"
            
            if (Test-Path $infoCenterPath) {
                $currentVal = (Get-ItemProperty -Path $infoCenterPath -Name "InfoCenterOn" -ErrorAction SilentlyContinue).InfoCenterOn
                Write-Host "  -> El InfoCenter actualmente tiene valor: $currentVal" -ForegroundColor Gray
            } else {
                Write-Host "  -> La clave InfoCenter aun no existe. (Se crearia al aplicar)" -ForegroundColor Gray
            }
            Write-Host "  -> Accion que tomaria el script: Cambiar 'InfoCenterOn' a 0." -ForegroundColor Green
        }
    } else {
        Write-Host "NO SE ENCONTRO NINGUNA VARIANTE DE AUTOCAD EN ESTE EQUIPO." -ForegroundColor Red
        Write-Host "Ruta explorada: HKCU:\Software\Autodesk\*[AutoCAD]*" -ForegroundColor Red
    }
    
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host "Presiona cualquier tecla para volver al menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Aplicar-Cambios($estado, $mensaje, $color) {
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor $color
    Write-Host "   $mensaje"
    Write-Host "==========================================================" -ForegroundColor $color
    
    $perfilesAutoCAD = Obtener-RutasAutoCAD
    
    if ($perfilesAutoCAD.Count -gt 0) {
        foreach ($perfil in $perfilesAutoCAD) {
            $infoCenterPath = "$($perfil.PSPath)\InfoCenter"
            
            if (-not (Test-Path $infoCenterPath)) {
                New-Item -Path $infoCenterPath -Force | Out-Null
                Write-Host "  [+] Creada ruta del registro para: $($perfil.PSChildName)"
            }
            
            Set-ItemProperty -Path $infoCenterPath -Name "InfoCenterOn" -Value $estado -Type DWord
            Write-Host "  [+] InfoCenter configurado a $estado en $($perfil.PSChildName)" -ForegroundColor Green
        }
        Write-Host "Proceso completado. Por favor, reinicia AutoCAD para ver los cambios." -ForegroundColor Cyan
    } else {
        Write-Host "No se modifico nada porque no se encontro AutoCAD instalado." -ForegroundColor Red
    }
    
    Write-Host "==========================================================" -ForegroundColor $color
    Write-Host "Presiona cualquier tecla para volver al menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Bucle principal del menu
while ($true) {
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "   GESTOR DE SESION DE AUTOCAD - CFT (V2 DINAMICA)"
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "1. Informacion: Que hace este script?"
    Write-Host "2. Pasada de prueba (Simular sin modificar nada)"
    Write-Host "3. Revertir cambios (MUESTRA el boton de cerrar sesion)"
    Write-Host "4. Aplicar cambios (OCULTA el boton de cerrar sesion)"
    Write-Host "5. Salir"
    Write-Host "==========================================================" -ForegroundColor Green
    
    $opcion = Read-Host "Selecciona una opcion (1-5)"
    
    switch ($opcion) {
        "1" { Mostrar-Informacion }
        "2" { Simulacion-Prueba }
        "3" { Aplicar-Cambios -estado 1 -mensaje "REVIRTIENDO CAMBIOS (HABILITANDO INFOCENTER)" -color "Yellow" }
        "4" { Aplicar-Cambios -estado 0 -mensaje "APLICANDO CAMBIOS (OCULTANDO INFOCENTER)" -color "Red" }
        "5" { 
            Write-Host "Saliendo del script..." -ForegroundColor Cyan
            Start-Sleep -Seconds 1
            break 
        }
        default { 
            Write-Host "Opcion no valida. Intenta de nuevo." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}