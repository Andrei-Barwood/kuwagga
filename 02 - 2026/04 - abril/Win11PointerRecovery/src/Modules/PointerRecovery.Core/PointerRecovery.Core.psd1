@{
    RootModule = 'PointerRecovery.Core.psm1'
    ModuleVersion = '1.0.0'
    GUID = '7493a226-2a70-4bd5-82bf-82f76c1f3f68'
    Author = 'Kirtan Teg Singh'
    CompanyName = 'www.sacred-geometry.uk'
    Copyright = '(c) 2026 Kirtan Teg Singh. MIT License.'
    Description = 'Core diagnostics, recovery, and local policy helpers for Win11 Pointer Recovery Toolkit.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Get-PRLogPath',
        'Initialize-PRLog',
        'Install-PRInputDrivers',
        'Invoke-PRDiagnostics',
        'Invoke-PRHardwareRescan',
        'Invoke-PRSystemRepair',
        'Reset-PRAccessibilitySettings',
        'Reset-PRCursorScheme',
        'Reset-PRInputSettings',
        'Reset-PRPrecisionTouchPadSettings',
        'Restart-PRInputDevices',
        'Remove-PRSystemToolBlock',
        'Set-PRSystemToolBlock',
        'Test-PRIsAdmin',
        'Test-PRIsWindows',
        'Test-PRWindows11',
        'Write-PRLog'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Windows11', 'Touchpad', 'Mouse', 'Cursor', 'Recovery', 'SecurityPolicy')
            LicenseUri = 'https://opensource.org/license/mit/'
            ProjectUri = 'https://www.sacred-geometry.uk'
        }
    }
}
