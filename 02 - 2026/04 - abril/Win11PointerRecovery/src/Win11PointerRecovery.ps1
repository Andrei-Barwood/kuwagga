<#
MIT License

Copyright (c) 2026 Kirtan Teg Singh

Developer: Kirtan Teg Singh
Website: www.sacred-geometry.uk

This script is the console entry point for Win11 Pointer Recovery Toolkit.
It intentionally supports standard-user diagnostics and current-user fixes,
then requests elevation only for driver, hardware, system repair, and local
policy actions.
#>

[CmdletBinding()]
param(
    [ValidateSet(
        'Menu',
        'Diagnose',
        'ResetCursor',
        'ResetInputSettings',
        'RestartInputDevices',
        'ReinstallInputDrivers',
        'RescanHardware',
        'RepairSystem',
        'AutoRecover',
        'AutoRecoverAdmin',
        'ApplySystemToolBlock',
        'RevertSystemToolBlock'
    )]
    [string]$Action = 'Menu',

    [string]$LogPath,

    [switch]$AcceptRisk,

    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'Modules\PointerRecovery.Core\PointerRecovery.Core.psd1'
Import-Module -Name $modulePath -Force
Initialize-PRLog -Path $LogPath

function Show-ToolkitBanner {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ' Win11 Pointer Recovery Toolkit' -ForegroundColor Cyan
    Write-Host ' Developer: Kirtan Teg Singh' -ForegroundColor Cyan
    Write-Host ' Website: www.sacred-geometry.uk' -ForegroundColor Cyan
    Write-Host ' License: MIT' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''
}

function Read-YesNo {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [bool]$Default = $false
    )

    $suffix = if ($Default) { '[Y/n]' } else { '[y/N]' }
    $answer = Read-Host "$Prompt $suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $Default
    }

    return $answer -match '^(y|yes|s|si)$'
}

function ConvertTo-ProcessArgument {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    return '"' + ($Value -replace '"', '\"') + '"'
}

function Get-CurrentPowerShellExe {
    try {
        $currentProcess = Get-Process -Id $PID -ErrorAction Stop
        if (-not [string]::IsNullOrWhiteSpace($currentProcess.Path)) {
            return $currentProcess.Path
        }
    }
    catch {
    }

    if ($PSVersionTable.PSEdition -eq 'Core') {
        return 'pwsh.exe'
    }

    return 'powershell.exe'
}

function Start-ElevatedAction {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not (Test-PRIsWindows)) {
        throw 'Elevation is available only on Windows.'
    }

    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $PSCommandPath,
        '-Action', $Name,
        '-LogPath', (Get-PRLogPath)
    )

    if ($AcceptRisk) {
        $arguments += '-AcceptRisk'
    }

    if ($NoPause) {
        $arguments += '-NoPause'
    }

    $argumentLine = ($arguments | ForEach-Object { ConvertTo-ProcessArgument -Value ([string]$_) }) -join ' '
    $exe = Get-CurrentPowerShellExe
    Write-PRLog -Level Warning -Message "Requesting administrator elevation for action: $Name"
    Start-Process -FilePath $exe -ArgumentList $argumentLine -Verb RunAs | Out-Null
}

function Test-ActionRequiresAdmin {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $adminActions = @(
        'RestartInputDevices',
        'ReinstallInputDrivers',
        'RescanHardware',
        'RepairSystem',
        'AutoRecoverAdmin',
        'ApplySystemToolBlock',
        'RevertSystemToolBlock'
    )

    return $Name -in $adminActions
}

function Confirm-PolicyBlock {
    if ($AcceptRisk) {
        return $true
    }

    Write-Host ''
    Write-Host 'This will block common command shells for non-administrative use through local policies.' -ForegroundColor Yellow
    Write-Host 'It is intended for managed/shared computers. Keep an administrator account available for reversal.' -ForegroundColor Yellow
    $confirmation = Read-Host 'Type BLOCK to continue'
    return $confirmation -eq 'BLOCK'
}

function Invoke-ToolkitAction {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ((Test-ActionRequiresAdmin -Name $Name) -and -not (Test-PRIsAdmin)) {
        Start-ElevatedAction -Name $Name
        return
    }

    switch ($Name) {
        'Diagnose' {
            Invoke-PRDiagnostics | Out-Null
        }
        'ResetCursor' {
            Reset-PRCursorScheme
            Reset-PRAccessibilitySettings
        }
        'ResetInputSettings' {
            Reset-PRInputSettings
        }
        'RestartInputDevices' {
            Restart-PRInputDevices -IncludeGenericMouseDevices
        }
        'ReinstallInputDrivers' {
            $removeAndRescan = $AcceptRisk
            if (-not $removeAndRescan -and -not $NoPause) {
                $removeAndRescan = Read-YesNo -Prompt 'Remove matching input devices so Windows reinstalls them from the driver store?' -Default $false
            }

            Install-PRInputDrivers -RemoveAndRescan:$removeAndRescan
        }
        'RescanHardware' {
            Invoke-PRHardwareRescan
        }
        'RepairSystem' {
            Invoke-PRSystemRepair
        }
        'AutoRecover' {
            Write-PRLog -Level Info -Message 'Starting automatic recovery: diagnostics, cursor reset, accessibility reset, touchpad reset.'
            Invoke-PRDiagnostics | Out-Null
            Reset-PRCursorScheme
            Reset-PRInputSettings

            if (Test-PRIsAdmin) {
                Invoke-ToolkitAction -Name 'AutoRecoverAdmin'
            }
            else {
                Write-PRLog -Level Warning -Message 'Automatic recovery now needs administrator privileges for device and hardware actions.'
                Start-ElevatedAction -Name 'AutoRecoverAdmin'
            }
        }
        'AutoRecoverAdmin' {
            Write-PRLog -Level Info -Message 'Continuing automatic recovery with administrator actions.'
            Restart-PRInputDevices -IncludeGenericMouseDevices
            Install-PRInputDrivers -RemoveAndRescan:$AcceptRisk
            Invoke-PRHardwareRescan

            $runSystemRepair = $AcceptRisk
            if (-not $runSystemRepair -and -not $NoPause) {
                $runSystemRepair = Read-YesNo -Prompt 'Run DISM and SFC system file repair now?' -Default $false
            }

            if ($runSystemRepair) {
                Invoke-PRSystemRepair
            }
        }
        'ApplySystemToolBlock' {
            if (Confirm-PolicyBlock) {
                Set-PRSystemToolBlock
            }
            else {
                Write-PRLog -Level Warning -Message 'System tool block was cancelled by the user.'
            }
        }
        'RevertSystemToolBlock' {
            Remove-PRSystemToolBlock
        }
        default {
            throw "Unknown action: $Name"
        }
    }
}

function Show-Menu {
    Show-ToolkitBanner
    Write-Host 'Select an option with the keyboard:' -ForegroundColor White
    Write-Host ''
    Write-Host ' 1. Diagnose pointer, touchpad, driver, and policy anomalies'
    Write-Host ' 2. Reset Windows cursor scheme and cursor accessibility settings'
    Write-Host ' 3. Reset Precision Touchpad and touch input settings'
    Write-Host ' 4. Restart touchpad/input devices (administrator)'
    Write-Host ' 5. Reinstall or refresh input drivers with Windows driver store (administrator)'
    Write-Host ' 6. Force hardware detection (administrator)'
    Write-Host ' 7. Repair system files with DISM and SFC (administrator)'
    Write-Host ' 8. Automatic recovery sequence'
    Write-Host ' 9. Apply optional system tool block after recovery (administrator)'
    Write-Host '10. Revert system tool block (administrator)'
    Write-Host ' 0. Exit'
    Write-Host ''
}

function Start-MenuLoop {
    do {
        Show-Menu
        $choice = Read-Host 'Option'

        try {
            switch ($choice) {
                '1' { Invoke-ToolkitAction -Name 'Diagnose' }
                '2' { Invoke-ToolkitAction -Name 'ResetCursor' }
                '3' { Invoke-ToolkitAction -Name 'ResetInputSettings' }
                '4' { Invoke-ToolkitAction -Name 'RestartInputDevices' }
                '5' { Invoke-ToolkitAction -Name 'ReinstallInputDrivers' }
                '6' { Invoke-ToolkitAction -Name 'RescanHardware' }
                '7' { Invoke-ToolkitAction -Name 'RepairSystem' }
                '8' { Invoke-ToolkitAction -Name 'AutoRecover' }
                '9' { Invoke-ToolkitAction -Name 'ApplySystemToolBlock' }
                '10' { Invoke-ToolkitAction -Name 'RevertSystemToolBlock' }
                '0' {
                    Write-PRLog -Level Info -Message 'User exited the toolkit.'
                    return
                }
                default {
                    Write-Host 'Invalid option.' -ForegroundColor Yellow
                }
            }
        }
        catch {
            Write-PRLog -Level Error -Message $_.Exception.Message
        }

        if (-not $NoPause) {
            [void](Read-Host 'Press Enter to continue')
        }
    } while ($true)
}

try {
    Show-ToolkitBanner
    try {
        Test-PRWindows11 -ThrowOnFailure
    }
    catch {
        Write-PRLog -Level Error -Message $_.Exception.Message
        if ($Action -ne 'Diagnose') {
            throw
        }
    }

    if ($Action -eq 'Menu') {
        Start-MenuLoop
    }
    else {
        Invoke-ToolkitAction -Name $Action
    }

    Write-PRLog -Level Success -Message 'Operation completed.'
}
catch {
    Write-PRLog -Level Error -Message $_.Exception.Message
    if (-not $NoPause) {
        [void](Read-Host 'Press Enter to exit')
    }
    exit 1
}
