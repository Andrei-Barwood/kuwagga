<#
MIT License

Copyright (c) 2026 Kirtan Teg Singh

Developer: Kirtan Teg Singh
Website: www.sacred-geometry.uk

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

$script:LogPath = $null
$script:PolicyDescriptionPrefix = 'Win11 Pointer Recovery Toolkit'
$script:BlockedShellExecutables = @(
    'cmd.exe',
    'powershell.exe',
    'powershell_ise.exe',
    'pwsh.exe',
    'wt.exe',
    'WindowsTerminal.exe',
    'OpenConsole.exe'
)

function Test-PRIsWindows {
    [CmdletBinding()]
    param()

    $isWindowsVariable = Get-Variable -Name IsWindows -ErrorAction SilentlyContinue
    if ($null -ne $isWindowsVariable) {
        return [bool]$isWindowsVariable.Value
    }

    return [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

function Test-PRIsAdmin {
    [CmdletBinding()]
    param()

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Get-PRDefaultLogPath {
    [CmdletBinding()]
    param()

    $root = $env:LOCALAPPDATA
    if ([string]::IsNullOrWhiteSpace($root)) {
        $root = $env:TEMP
    }

    if ([string]::IsNullOrWhiteSpace($root)) {
        $root = [System.IO.Path]::GetTempPath()
    }

    if (Test-PRIsAdmin -and -not [string]::IsNullOrWhiteSpace($env:ProgramData)) {
        $root = $env:ProgramData
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logDirectory = Join-Path -Path (Join-Path -Path $root -ChildPath 'Win11PointerRecovery') -ChildPath 'Logs'
    return Join-Path -Path $logDirectory -ChildPath "Win11PointerRecovery-$stamp.log"
}

function Initialize-PRLog {
    [CmdletBinding()]
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = Get-PRDefaultLogPath
    }

    $directory = Split-Path -Path $Path -Parent
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    $script:LogPath = $Path
    $header = @(
        'Win11 Pointer Recovery Toolkit',
        'Developer: Kirtan Teg Singh',
        'Website: www.sacred-geometry.uk',
        "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        ''
    )
    Set-Content -LiteralPath $script:LogPath -Value $header -Encoding UTF8
    Write-PRLog -Level Info -Message "Log file: $script:LogPath"
}

function Get-PRLogPath {
    [CmdletBinding()]
    param()

    return $script:LogPath
}

function Write-PRLog {
    [CmdletBinding()]
    param(
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info',

        [Parameter(Mandatory)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"

    if (-not [string]::IsNullOrWhiteSpace($script:LogPath)) {
        Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8
    }

    $color = switch ($Level) {
        'Error' { 'Red' }
        'Warning' { 'Yellow' }
        'Success' { 'Green' }
        default { 'Gray' }
    }

    Write-Host $line -ForegroundColor $color
}

function Test-PRWindows11 {
    [CmdletBinding()]
    param(
        [switch]$ThrowOnFailure
    )

    if (-not (Test-PRIsWindows)) {
        if ($ThrowOnFailure) {
            throw 'This toolkit is compatible only with Windows 11.'
        }

        return $false
    }

    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 22000) {
        if ($ThrowOnFailure) {
            throw "This toolkit requires Windows 11 build 22000 or later. Detected build: $build."
        }

        return $false
    }

    return $true
}

function New-PRRegistryKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
}

function Set-PRRegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowNull()]
        $Value,

        [ValidateSet('String', 'DWord', 'QWord', 'Binary', 'MultiString', 'ExpandString')]
        [string]$Type = 'String'
    )

    New-PRRegistryKey -Path $Path

    New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Get-PRRegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name
    )

    try {
        $item = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop
        return $item.$Name
    }
    catch {
        return $null
    }
}

function Invoke-PRNativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [int[]]$SuccessExitCodes = @(0)
    )

    $display = "$FilePath $($Arguments -join ' ')".Trim()
    Write-PRLog -Level Info -Message "Running: $display"

    & $FilePath @Arguments 2>&1 | ForEach-Object {
        if (-not [string]::IsNullOrWhiteSpace([string]$_)) {
            Write-PRLog -Level Info -Message "$_"
        }
    }

    $exitCode = $LASTEXITCODE
    if ($exitCode -notin $SuccessExitCodes) {
        throw "Command failed with exit code ${exitCode}: $display"
    }
}

function Add-PRFinding {
    [CmdletBinding()]
    param(
        [System.Collections.Generic.List[object]]$Findings,

        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Severity,

        [string]$Area,
        [string]$Message,
        [string]$Evidence,
        [string]$SuggestedFix
    )

    $Findings.Add([pscustomobject]@{
        Severity = $Severity
        Area = $Area
        Message = $Message
        Evidence = $Evidence
        SuggestedFix = $SuggestedFix
    }) | Out-Null
}

function Get-PRInputDeviceCandidates {
    [CmdletBinding()]
    param(
        [switch]$IncludeGenericMouseDevices
    )

    if (-not (Get-Command -Name Get-PnpDevice -ErrorAction SilentlyContinue)) {
        Write-PRLog -Level Warning -Message 'Get-PnpDevice is not available on this system. Device-level repairs will use pnputil when possible.'
        return @()
    }

    try {
        $allDevices = @(Get-PnpDevice -ErrorAction Stop)
    }
    catch {
        Write-PRLog -Level Error -Message "Unable to query PnP devices: $($_.Exception.Message)"
        return @()
    }

    $inputClasses = @($allDevices | Where-Object {
        $_.Class -in @('Mouse', 'HIDClass') -or
        $_.InstanceId -like 'HID\*' -or
        $_.InstanceId -like 'ACPI\*'
    })

    $touchpadPattern = '(?i)touchpad|trackpad|precision|synaptics|elan|alps|etd|i2c hid|hid-compliant touch'
    $touchpadDevices = @($inputClasses | Where-Object {
        $text = @($_.FriendlyName, $_.Name, $_.Manufacturer, $_.InstanceId) -join ' '
        $text -match $touchpadPattern
    })

    $selected = $touchpadDevices
    if ($selected.Count -eq 0 -and $IncludeGenericMouseDevices) {
        $selected = @($allDevices | Where-Object { $_.Class -eq 'Mouse' })
    }

    $unique = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    foreach ($device in $selected) {
        if ([string]::IsNullOrWhiteSpace($device.InstanceId)) {
            continue
        }

        if (-not $seen.ContainsKey($device.InstanceId)) {
            $seen[$device.InstanceId] = $true
            $unique.Add($device) | Out-Null
        }
    }

    return @($unique)
}

function Invoke-PRDiagnostics {
    [CmdletBinding()]
    param()

    Write-PRLog -Level Info -Message 'Starting diagnostics.'
    $findings = [System.Collections.Generic.List[object]]::new()
    $windowsReady = $true

    try {
        Test-PRWindows11 -ThrowOnFailure
        $osCaption = 'Windows 11'
        try {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            $osCaption = "$($os.Caption) $($os.Version) build $($os.BuildNumber)"
        }
        catch {
            $osCaption = [System.Environment]::OSVersion.VersionString
        }

        Add-PRFinding -Findings $findings -Severity Info -Area 'Operating system' -Message 'Windows 11 compatibility check passed.' -Evidence $osCaption -SuggestedFix 'No action required.'
    }
    catch {
        Add-PRFinding -Findings $findings -Severity Error -Area 'Operating system' -Message 'Unsupported operating system.' -Evidence $_.Exception.Message -SuggestedFix 'Run this toolkit on Windows 11 only.'
        $windowsReady = $false
    }

    if (-not $windowsReady) {
        foreach ($finding in $findings) {
            $message = '{0}: {1} Evidence: {2} Suggested fix: {3}' -f $finding.Area, $finding.Message, $finding.Evidence, $finding.SuggestedFix
            Write-PRLog -Level $finding.Severity -Message $message
        }

        return @($findings)
    }

    if (Test-PRIsAdmin) {
        Add-PRFinding -Findings $findings -Severity Info -Area 'Privileges' -Message 'The process is running with administrator privileges.' -Evidence 'Administrator token detected.' -SuggestedFix 'Administrative repairs are available.'
    }
    else {
        Add-PRFinding -Findings $findings -Severity Warning -Area 'Privileges' -Message 'The process is running as a standard user.' -Evidence 'No administrator token detected.' -SuggestedFix 'The toolkit will request elevation for driver, hardware, repair, or policy actions.'
    }

    $cursorKey = 'HKCU:\Control Panel\Cursors'
    $importantCursorNames = @('Arrow', 'Help', 'AppStarting', 'Wait', 'IBeam', 'No', 'SizeNS', 'SizeWE', 'SizeNWSE', 'SizeNESW', 'SizeAll', 'UpArrow', 'Hand', 'Pin', 'Person')
    if (Test-Path -LiteralPath $cursorKey) {
        foreach ($cursorName in $importantCursorNames) {
            $value = Get-PRRegistryValue -Path $cursorKey -Name $cursorName
            if ($null -eq $value) {
                Add-PRFinding -Findings $findings -Severity Warning -Area 'Cursor scheme' -Message "Cursor value '$cursorName' is missing." -Evidence $cursorKey -SuggestedFix 'Reset the Windows cursor scheme.'
                continue
            }

            if ($cursorName -in @('Arrow', 'Help', 'AppStarting', 'Wait', 'No', 'SizeNS', 'SizeWE', 'SizeNWSE', 'SizeNESW', 'SizeAll', 'UpArrow', 'Hand') -and [string]::IsNullOrWhiteSpace([string]$value)) {
                Add-PRFinding -Findings $findings -Severity Warning -Area 'Cursor scheme' -Message "Cursor value '$cursorName' is empty." -Evidence $cursorKey -SuggestedFix 'Reset the Windows cursor scheme.'
                continue
            }

            if ([string]$value -match '\.(cur|ani)$') {
                $expanded = [System.Environment]::ExpandEnvironmentVariables([string]$value)
                if (-not (Test-Path -LiteralPath $expanded)) {
                    Add-PRFinding -Findings $findings -Severity Error -Area 'Cursor scheme' -Message "Cursor file for '$cursorName' does not exist." -Evidence $value -SuggestedFix 'Reset the Windows cursor scheme and run system file repair if the file is still missing.'
                }
            }
        }
    }
    else {
        Add-PRFinding -Findings $findings -Severity Error -Area 'Cursor scheme' -Message 'The cursor registry key is missing.' -Evidence $cursorKey -SuggestedFix 'Reset the Windows cursor scheme.'
    }

    $mouseKey = 'HKCU:\Control Panel\Mouse'
    $mouseTrails = Get-PRRegistryValue -Path $mouseKey -Name 'MouseTrails'
    if ($null -ne $mouseTrails -and [string]$mouseTrails -ne '0') {
        Add-PRFinding -Findings $findings -Severity Warning -Area 'Mouse settings' -Message 'Mouse trails are enabled or set to an unusual value.' -Evidence "MouseTrails=$mouseTrails" -SuggestedFix 'Reset mouse accessibility settings.'
    }

    $accessibilityKey = 'HKCU:\Software\Microsoft\Accessibility'
    $cursorSize = Get-PRRegistryValue -Path $accessibilityKey -Name 'CursorSize'
    if ($null -ne $cursorSize -and ([int]$cursorSize -lt 1 -or [int]$cursorSize -gt 15)) {
        Add-PRFinding -Findings $findings -Severity Warning -Area 'Accessibility' -Message 'Mouse pointer size is outside the normal Windows range.' -Evidence "CursorSize=$cursorSize" -SuggestedFix 'Reset accessibility cursor settings.'
    }

    $touchPadKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad'
    $touchPadEnabled = Get-PRRegistryValue -Path $touchPadKey -Name 'Enabled'
    if ($null -ne $touchPadEnabled -and [int]$touchPadEnabled -eq 0) {
        Add-PRFinding -Findings $findings -Severity Warning -Area 'Touchpad settings' -Message 'Precision Touchpad appears to be disabled for the current user.' -Evidence "Enabled=$touchPadEnabled" -SuggestedFix 'Reset touchpad input settings.'
    }

    $devices = @(Get-PRInputDeviceCandidates -IncludeGenericMouseDevices)
    if ($devices.Count -eq 0) {
        Add-PRFinding -Findings $findings -Severity Warning -Area 'Input devices' -Message 'No touchpad or mouse-class PnP devices were detected by PowerShell.' -Evidence 'Get-PnpDevice returned no candidates.' -SuggestedFix 'Force hardware detection or inspect Device Manager.'
    }
    else {
        foreach ($device in $devices) {
            $status = [string]$device.Status
            $name = if ($device.FriendlyName) { $device.FriendlyName } else { $device.InstanceId }
            if ($status -notin @('OK', 'Unknown')) {
                Add-PRFinding -Findings $findings -Severity Error -Area 'Input devices' -Message "Input device '$name' reports a non-OK status." -Evidence "Status=$status; Problem=$($device.Problem)" -SuggestedFix 'Restart or reinstall the device driver.'
            }
            else {
                Add-PRFinding -Findings $findings -Severity Info -Area 'Input devices' -Message "Input device '$name' is present." -Evidence "Status=$status" -SuggestedFix 'No action required unless the pointer is still invisible.'
            }
        }
    }

    try {
        $drivers = @(Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop | Where-Object {
            $_.DeviceClass -in @('MOUSE', 'HIDCLASS') -and
            (@($_.DeviceName, $_.FriendlyName, $_.Manufacturer) -join ' ') -match '(?i)touchpad|trackpad|mouse|hid|synaptics|elan|alps'
        })

        foreach ($driver in $drivers) {
            if ([string]::IsNullOrWhiteSpace($driver.DriverVersion)) {
                Add-PRFinding -Findings $findings -Severity Warning -Area 'Drivers' -Message "Driver version is missing for '$($driver.DeviceName)'." -Evidence $driver.InfName -SuggestedFix 'Reinstall or update the input driver.'
            }
        }
    }
    catch {
        Add-PRFinding -Findings $findings -Severity Warning -Area 'Drivers' -Message 'Unable to query signed input drivers.' -Evidence $_.Exception.Message -SuggestedFix 'Run diagnostics from an elevated Windows PowerShell session.'
    }

    $rebootKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($key in $rebootKeys) {
        if (Test-Path -LiteralPath $key) {
            Add-PRFinding -Findings $findings -Severity Warning -Area 'Pending reboot' -Message 'Windows reports a pending reboot.' -Evidence $key -SuggestedFix 'Restart Windows after repair actions complete.'
        }
    }

    if ($findings.Count -eq 0) {
        Add-PRFinding -Findings $findings -Severity Info -Area 'Diagnostics' -Message 'No anomalies were detected by the automated checks.' -Evidence 'All checks completed.' -SuggestedFix 'Run the recovery actions if the pointer remains invisible.'
    }

    foreach ($finding in $findings) {
        $message = '{0}: {1} Evidence: {2} Suggested fix: {3}' -f $finding.Area, $finding.Message, $finding.Evidence, $finding.SuggestedFix
        Write-PRLog -Level $finding.Severity -Message $message
    }

    return @($findings)
}

function Invoke-PRCursorRefresh {
    [CmdletBinding()]
    param()

    $source = @'
using System;
using System.Runtime.InteropServices;

public static class CursorSystemParameters
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uiAction, int uiParam, IntPtr pvParam, int fWinIni);
}
'@

    try {
        if (-not ('CursorSystemParameters' -as [type])) {
            Add-Type -TypeDefinition $source -ErrorAction Stop
        }

        $SPI_SETCURSORS = 0x0057
        $SPIF_UPDATEINIFILE = 0x01
        $SPIF_SENDCHANGE = 0x02
        [CursorSystemParameters]::SystemParametersInfo($SPI_SETCURSORS, 0, [IntPtr]::Zero, ($SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE)) | Out-Null
        Write-PRLog -Level Success -Message 'Cursor cache refresh requested.'
    }
    catch {
        Write-PRLog -Level Warning -Message "Unable to refresh cursor cache automatically: $($_.Exception.Message)"
    }
}

function Reset-PRCursorScheme {
    [CmdletBinding()]
    param()

    Test-PRWindows11 -ThrowOnFailure
    Write-PRLog -Level Info -Message 'Resetting Windows cursor scheme to the default Aero cursor set.'

    $cursorKey = 'HKCU:\Control Panel\Cursors'
    New-PRRegistryKey -Path $cursorKey

    $defaults = [ordered]@{
        'Arrow' = '%SystemRoot%\cursors\aero_arrow.cur'
        'Help' = '%SystemRoot%\cursors\aero_helpsel.cur'
        'AppStarting' = '%SystemRoot%\cursors\aero_working.ani'
        'Wait' = '%SystemRoot%\cursors\aero_busy.ani'
        'Crosshair' = ''
        'IBeam' = ''
        'NWPen' = '%SystemRoot%\cursors\aero_pen.cur'
        'No' = '%SystemRoot%\cursors\aero_unavail.cur'
        'SizeNS' = '%SystemRoot%\cursors\aero_ns.cur'
        'SizeWE' = '%SystemRoot%\cursors\aero_ew.cur'
        'SizeNWSE' = '%SystemRoot%\cursors\aero_nwse.cur'
        'SizeNESW' = '%SystemRoot%\cursors\aero_nesw.cur'
        'SizeAll' = '%SystemRoot%\cursors\aero_move.cur'
        'UpArrow' = '%SystemRoot%\cursors\aero_up.cur'
        'Hand' = '%SystemRoot%\cursors\aero_link.cur'
        'Pin' = '%SystemRoot%\cursors\aero_pin.cur'
        'Person' = '%SystemRoot%\cursors\aero_person.cur'
    }

    foreach ($entry in $defaults.GetEnumerator()) {
        Set-PRRegistryValue -Path $cursorKey -Name $entry.Key -Value $entry.Value -Type ExpandString
    }

    Set-PRRegistryValue -Path $cursorKey -Name 'Scheme Source' -Value 2 -Type DWord

    $rawKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Control Panel\Cursors', $true)
    if ($null -ne $rawKey) {
        try {
            $rawKey.SetValue('', 'Windows Default', [Microsoft.Win32.RegistryValueKind]::String)
        }
        finally {
            $rawKey.Dispose()
        }
    }

    Invoke-PRCursorRefresh
    Write-PRLog -Level Success -Message 'Cursor scheme reset completed.'
}

function Reset-PRAccessibilitySettings {
    [CmdletBinding()]
    param()

    Test-PRWindows11 -ThrowOnFailure
    Write-PRLog -Level Info -Message 'Resetting cursor-related accessibility settings for the current user.'

    Set-PRRegistryValue -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseTrails' -Value '0' -Type String
    Set-PRRegistryValue -Path 'HKCU:\Software\Microsoft\Accessibility' -Name 'CursorSize' -Value 1 -Type DWord
    Set-PRRegistryValue -Path 'HKCU:\Software\Microsoft\Accessibility' -Name 'CursorType' -Value 0 -Type DWord
    Set-PRRegistryValue -Path 'HKCU:\Software\Microsoft\Accessibility' -Name 'CursorColor' -Value 0 -Type DWord
    Invoke-PRCursorRefresh

    Write-PRLog -Level Success -Message 'Accessibility cursor settings reset completed.'
}

function Reset-PRPrecisionTouchPadSettings {
    [CmdletBinding()]
    param()

    Test-PRWindows11 -ThrowOnFailure
    Write-PRLog -Level Info -Message 'Resetting Precision Touchpad settings for the current user.'

    $touchPadKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad'
    Set-PRRegistryValue -Path $touchPadKey -Name 'Enabled' -Value 1 -Type DWord
    Set-PRRegistryValue -Path $touchPadKey -Name 'LeaveOnWithMouse' -Value 1 -Type DWord
    Set-PRRegistryValue -Path $touchPadKey -Name 'TapsEnabled' -Value 1 -Type DWord
    Set-PRRegistryValue -Path $touchPadKey -Name 'PanEnabled' -Value 1 -Type DWord

    Write-PRLog -Level Success -Message 'Precision Touchpad settings reset completed.'
}

function Reset-PRInputSettings {
    [CmdletBinding()]
    param()

    Reset-PRAccessibilitySettings
    Reset-PRPrecisionTouchPadSettings

    $services = @(
        'TabletInputService',
        'hidserv',
        'SynTPEnhService',
        'SynTPEnh',
        'ETDService',
        'ElanService',
        'ApHidMonitorService'
    )
    foreach ($serviceName in $services) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($null -eq $service) {
                Write-PRLog -Level Info -Message "Service not present: $serviceName"
                continue
            }

            if (Test-PRIsAdmin) {
                if ($service.Status -eq 'Running') {
                    Restart-Service -Name $serviceName -Force -ErrorAction Stop
                    Write-PRLog -Level Success -Message "Service restarted: $serviceName"
                }
                else {
                    Start-Service -Name $serviceName -ErrorAction Stop
                    Write-PRLog -Level Success -Message "Service started: $serviceName"
                }
            }
            else {
                Write-PRLog -Level Warning -Message "Service '$serviceName' was found but cannot be restarted without administrator privileges."
            }
        }
        catch {
            Write-PRLog -Level Warning -Message "Service '$serviceName' could not be processed: $($_.Exception.Message)"
        }
    }
}

function Restart-PRInputDevices {
    [CmdletBinding()]
    param(
        [switch]$IncludeGenericMouseDevices
    )

    Test-PRWindows11 -ThrowOnFailure
    if (-not (Test-PRIsAdmin)) {
        throw 'Restarting input devices requires administrator privileges.'
    }

    Write-PRLog -Level Info -Message 'Restarting touchpad and mouse-class input devices.'
    $devices = @(Get-PRInputDeviceCandidates -IncludeGenericMouseDevices:$IncludeGenericMouseDevices)

    if ($devices.Count -eq 0) {
        Write-PRLog -Level Warning -Message 'No device candidates found. Running a hardware rescan instead.'
        Invoke-PRHardwareRescan
        return
    }

    foreach ($device in $devices) {
        $name = if ($device.FriendlyName) { $device.FriendlyName } else { $device.InstanceId }
        Write-PRLog -Level Info -Message "Restarting device: $name"

        $usedPnPUtil = $false
        try {
            if (Get-Command -Name Disable-PnpDevice -ErrorAction SilentlyContinue) {
                Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop | Out-Null
                Start-Sleep -Seconds 2
                Enable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop | Out-Null
                Write-PRLog -Level Success -Message "Device restarted through PowerShell PnP cmdlets: $name"
            }
            else {
                $usedPnPUtil = $true
            }
        }
        catch {
            Write-PRLog -Level Warning -Message "PowerShell PnP restart failed for '$name': $($_.Exception.Message)"
            $usedPnPUtil = $true
        }

        if ($usedPnPUtil) {
            try {
                Invoke-PRNativeCommand -FilePath 'pnputil.exe' -Arguments @('/restart-device', $device.InstanceId)
                Write-PRLog -Level Success -Message "Device restart requested through pnputil: $name"
            }
            catch {
                Write-PRLog -Level Error -Message "pnputil restart failed for '$name': $($_.Exception.Message)"
            }
        }
    }

    Invoke-PRHardwareRescan
}

function Install-PRInputDrivers {
    [CmdletBinding()]
    param(
        [switch]$RemoveAndRescan
    )

    Test-PRWindows11 -ThrowOnFailure
    if (-not (Test-PRIsAdmin)) {
        throw 'Reinstalling input drivers requires administrator privileges.'
    }

    Write-PRLog -Level Info -Message 'Preparing input driver restart/reinstall workflow.'
    $devices = @(Get-PRInputDeviceCandidates -IncludeGenericMouseDevices)
    if ($devices.Count -eq 0) {
        Write-PRLog -Level Warning -Message 'No input devices were found for driver reinstall. Running hardware rescan.'
        Invoke-PRHardwareRescan
        return
    }

    foreach ($device in $devices) {
        $name = if ($device.FriendlyName) { $device.FriendlyName } else { $device.InstanceId }
        try {
            Invoke-PRNativeCommand -FilePath 'pnputil.exe' -Arguments @('/restart-device', $device.InstanceId)
            Write-PRLog -Level Success -Message "Driver restart requested: $name"
        }
        catch {
            Write-PRLog -Level Warning -Message "Driver restart request failed for '$name': $($_.Exception.Message)"
        }

        if ($RemoveAndRescan) {
            try {
                Write-PRLog -Level Warning -Message "Removing device so Windows can reinstall it from the driver store: $name"
                Invoke-PRNativeCommand -FilePath 'pnputil.exe' -Arguments @('/remove-device', $device.InstanceId)
                Write-PRLog -Level Success -Message "Device remove request completed: $name"
            }
            catch {
                Write-PRLog -Level Error -Message "Device remove request failed for '$name': $($_.Exception.Message)"
            }
        }
    }

    Invoke-PRHardwareRescan
}

function Invoke-PRHardwareRescan {
    [CmdletBinding()]
    param()

    Test-PRWindows11 -ThrowOnFailure
    if (-not (Test-PRIsAdmin)) {
        throw 'Forcing hardware detection requires administrator privileges.'
    }

    Write-PRLog -Level Info -Message 'Forcing Windows to rescan Plug and Play devices.'
    Invoke-PRNativeCommand -FilePath 'pnputil.exe' -Arguments @('/scan-devices')
    Write-PRLog -Level Success -Message 'Hardware rescan requested.'
}

function Invoke-PRSystemRepair {
    [CmdletBinding()]
    param()

    Test-PRWindows11 -ThrowOnFailure
    if (-not (Test-PRIsAdmin)) {
        throw 'SFC and DISM repairs require administrator privileges.'
    }

    Write-PRLog -Level Warning -Message 'System repair can take a long time. Keep the computer powered on.'
    Invoke-PRNativeCommand -FilePath 'DISM.exe' -Arguments @('/Online', '/Cleanup-Image', '/RestoreHealth')
    Invoke-PRNativeCommand -FilePath 'sfc.exe' -Arguments @('/scannow')
    Write-PRLog -Level Success -Message 'System repair commands completed.'
}

function Backup-PRPolicyRegistryKeys {
    [CmdletBinding()]
    param()

    $backupRoot = Join-Path -Path (Split-Path -Path $script:LogPath -Parent) -ChildPath ('PolicyBackup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -Path $backupRoot -ItemType Directory -Force | Out-Null

    $exports = @(
        @{ Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Safer'; File = 'HKLM-Safer.reg' },
        @{ Key = 'HKCU\Software\Policies\Microsoft\Windows\System'; File = 'HKCU-Windows-System.reg' },
        @{ Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'; File = 'HKCU-Explorer.reg' }
    )

    foreach ($export in $exports) {
        $destination = Join-Path -Path $backupRoot -ChildPath $export.File
        try {
            & reg.exe export $export.Key $destination /y 2>&1 | ForEach-Object {
                if (-not [string]::IsNullOrWhiteSpace([string]$_)) {
                    Write-PRLog -Level Info -Message "$_"
                }
            }
            if ($LASTEXITCODE -eq 0) {
                Write-PRLog -Level Success -Message "Registry backup created: $destination"
            }
            else {
                Write-PRLog -Level Warning -Message "Registry key was not exported, likely because it does not exist: $($export.Key)"
            }
        }
        catch {
            Write-PRLog -Level Warning -Message "Registry backup failed for $($export.Key): $($_.Exception.Message)"
        }
    }
}

function Get-PRSrpBlockedPaths {
    [CmdletBinding()]
    param()

    return @(
        '%SystemRoot%\System32\cmd.exe',
        '%SystemRoot%\SysWOW64\cmd.exe',
        '%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe',
        '%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe',
        '%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell_ise.exe',
        '%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell_ise.exe',
        '%ProgramFiles%\PowerShell\*\pwsh.exe',
        '%ProgramFiles(x86)%\PowerShell\*\pwsh.exe',
        '%LocalAppData%\Microsoft\WindowsApps\pwsh.exe',
        '%LocalAppData%\Microsoft\WindowsApps\powershell.exe',
        '%LocalAppData%\Microsoft\WindowsApps\wt.exe',
        '%ProgramFiles%\WindowsApps\Microsoft.PowerShell_*\pwsh.exe',
        '%ProgramFiles%\WindowsApps\Microsoft.WindowsTerminal_*\wt.exe'
    )
}

function Remove-PRTaggedSrpRules {
    [CmdletBinding()]
    param()

    $pathsRoot = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers\0\Paths'
    if (-not (Test-Path -LiteralPath $pathsRoot)) {
        return
    }

    foreach ($rule in Get-ChildItem -LiteralPath $pathsRoot -ErrorAction SilentlyContinue) {
        $description = Get-PRRegistryValue -Path $rule.PSPath -Name 'Description'
        if ([string]$description -like "${script:PolicyDescriptionPrefix}*") {
            Remove-Item -LiteralPath $rule.PSPath -Recurse -Force
            Write-PRLog -Level Info -Message "Removed existing toolkit SRP rule: $($rule.PSChildName)"
        }
    }
}

function Add-PRSrpPathRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PathPattern
    )

    $ruleGuid = [guid]::NewGuid().ToString('B')
    $rulePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers\0\Paths\$ruleGuid"
    New-PRRegistryKey -Path $rulePath
    Set-PRRegistryValue -Path $rulePath -Name 'Description' -Value "${script:PolicyDescriptionPrefix} - block $PathPattern" -Type String
    Set-PRRegistryValue -Path $rulePath -Name 'ItemData' -Value $PathPattern -Type String
    Set-PRRegistryValue -Path $rulePath -Name 'SaferFlags' -Value 0 -Type DWord
    Write-PRLog -Level Success -Message "SRP disallow path rule added: $PathPattern"
}

function Get-PRLoadedUserRoots {
    [CmdletBinding()]
    param()

    $roots = @()
    try {
        $roots = @(Get-ChildItem -Path 'Registry::HKEY_USERS' -ErrorAction Stop | Where-Object {
            $_.PSChildName -match '^S-\d-\d+-.+' -and $_.PSChildName -notlike '*_Classes'
        })
    }
    catch {
        Write-PRLog -Level Warning -Message "Unable to enumerate loaded user registry hives: $($_.Exception.Message)"
    }

    return $roots
}

function Get-PRLocalAdministratorSids {
    [CmdletBinding()]
    param()

    $adminSids = @{}

    try {
        if (Test-PRIsAdmin) {
            $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            if (-not [string]::IsNullOrWhiteSpace($currentSid)) {
                $adminSids[$currentSid] = $true
            }
        }
    }
    catch {
    }

    try {
        $administratorsSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
        $administratorsName = $administratorsSid.Translate([Security.Principal.NTAccount]).Value.Split('\')[-1]
        $computerName = if ([string]::IsNullOrWhiteSpace($env:COMPUTERNAME)) { '.' } else { $env:COMPUTERNAME }
        $group = [ADSI]"WinNT://$computerName/$administratorsName,group"
        $members = @($group.psbase.Invoke('Members'))

        foreach ($member in $members) {
            $sidBytes = $member.GetType().InvokeMember('objectSid', 'GetProperty', $null, $member, $null)
            if ($null -ne $sidBytes) {
                $sid = [Security.Principal.SecurityIdentifier]::new([byte[]]$sidBytes, 0).Value
                $adminSids[$sid] = $true
            }
        }
    }
    catch {
        Write-PRLog -Level Warning -Message "Unable to enumerate local administrator SIDs. Current elevated account will still be skipped when possible: $($_.Exception.Message)"
    }

    return $adminSids
}

function Set-PRLoadedUserShellPolicy {
    [CmdletBinding()]
    param()

    $adminSids = Get-PRLocalAdministratorSids
    foreach ($root in Get-PRLoadedUserRoots) {
        $sid = $root.PSChildName
        if ($adminSids.ContainsKey($sid)) {
            Write-PRLog -Level Info -Message "Skipping administrator hive for user shell launch policies: $sid"
            continue
        }

        $systemPath = "Registry::HKEY_USERS\$sid\Software\Policies\Microsoft\Windows\System"
        Set-PRRegistryValue -Path $systemPath -Name 'DisableCMD' -Value 1 -Type DWord

        $explorerPath = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        $disallowPath = "$explorerPath\DisallowRun"
        Set-PRRegistryValue -Path $explorerPath -Name 'DisallowRun' -Value 1 -Type DWord
        New-PRRegistryKey -Path $disallowPath

        $index = 1
        foreach ($executable in $script:BlockedShellExecutables) {
            Set-PRRegistryValue -Path $disallowPath -Name ([string]$index) -Value $executable -Type String
            $index++
        }

        Write-PRLog -Level Success -Message "User shell launch policies applied to loaded hive: $sid"
    }
}

function Remove-PRLoadedUserShellPolicy {
    [CmdletBinding()]
    param()

    foreach ($root in Get-PRLoadedUserRoots) {
        $sid = $root.PSChildName
        $systemPath = "Registry::HKEY_USERS\$sid\Software\Policies\Microsoft\Windows\System"
        if (Test-Path -LiteralPath $systemPath) {
            Remove-ItemProperty -LiteralPath $systemPath -Name 'DisableCMD' -ErrorAction SilentlyContinue
        }

        $explorerPath = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        $disallowPath = "$explorerPath\DisallowRun"

        if (Test-Path -LiteralPath $disallowPath) {
            foreach ($property in (Get-ItemProperty -LiteralPath $disallowPath -ErrorAction SilentlyContinue).PSObject.Properties) {
                if ($property.Name -match '^\d+$' -and $property.Value -in $script:BlockedShellExecutables) {
                    Remove-ItemProperty -LiteralPath $disallowPath -Name $property.Name -ErrorAction SilentlyContinue
                }
            }

            $remainingEntries = @((Get-ItemProperty -LiteralPath $disallowPath -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -match '^\d+$' })
            if ($remainingEntries.Count -eq 0) {
                Remove-Item -LiteralPath $disallowPath -Recurse -Force -ErrorAction SilentlyContinue
                if (Test-Path -LiteralPath $explorerPath) {
                    Remove-ItemProperty -LiteralPath $explorerPath -Name 'DisallowRun' -ErrorAction SilentlyContinue
                }
            }
        }

        Write-PRLog -Level Success -Message "User shell launch policies removed from loaded hive: $sid"
    }
}

function Set-PRSystemToolBlock {
    [CmdletBinding()]
    param()

    Test-PRWindows11 -ThrowOnFailure
    if (-not (Test-PRIsAdmin)) {
        throw 'Applying system tool blocks requires administrator privileges.'
    }

    Write-PRLog -Level Warning -Message 'Applying local policies that block common command shells for non-administrative use.'
    Backup-PRPolicyRegistryKeys

    $srpBase = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers'
    New-PRRegistryKey -Path $srpBase
    Set-PRRegistryValue -Path $srpBase -Name 'DefaultLevel' -Value 262144 -Type DWord
    Set-PRRegistryValue -Path $srpBase -Name 'TransparentEnabled' -Value 1 -Type DWord
    # PolicyScope 1 is the local SRP enforcement option for all users except local administrators.
    Set-PRRegistryValue -Path $srpBase -Name 'PolicyScope' -Value 1 -Type DWord
    Set-PRRegistryValue -Path $srpBase -Name 'AuthenticodeEnabled' -Value 0 -Type DWord
    New-PRRegistryKey -Path "$srpBase\0\Paths"

    Remove-PRTaggedSrpRules
    foreach ($pathPattern in Get-PRSrpBlockedPaths) {
        Add-PRSrpPathRule -PathPattern $pathPattern
    }

    Set-PRLoadedUserShellPolicy

    try {
        Invoke-PRNativeCommand -FilePath 'gpupdate.exe' -Arguments @('/target:computer', '/force') -SuccessExitCodes @(0, 1)
        Invoke-PRNativeCommand -FilePath 'gpupdate.exe' -Arguments @('/target:user', '/force') -SuccessExitCodes @(0, 1)
    }
    catch {
        Write-PRLog -Level Warning -Message "Group Policy refresh did not complete cleanly: $($_.Exception.Message)"
    }

    Write-PRLog -Level Success -Message 'System tool block policy applied. A sign-out/sign-in or restart may be required for every user session.'
    Write-PRLog -Level Warning -Message 'Use RevertSystemToolBlock or the README manual steps from an administrator account to undo this policy.'
}

function Remove-PRSystemToolBlock {
    [CmdletBinding()]
    param()

    Test-PRWindows11 -ThrowOnFailure
    if (-not (Test-PRIsAdmin)) {
        throw 'Reverting system tool blocks requires administrator privileges.'
    }

    Write-PRLog -Level Warning -Message 'Removing toolkit-created command shell block policies.'
    Remove-PRTaggedSrpRules
    Remove-PRLoadedUserShellPolicy

    try {
        Invoke-PRNativeCommand -FilePath 'gpupdate.exe' -Arguments @('/target:computer', '/force') -SuccessExitCodes @(0, 1)
        Invoke-PRNativeCommand -FilePath 'gpupdate.exe' -Arguments @('/target:user', '/force') -SuccessExitCodes @(0, 1)
    }
    catch {
        Write-PRLog -Level Warning -Message "Group Policy refresh did not complete cleanly: $($_.Exception.Message)"
    }

    Write-PRLog -Level Success -Message 'Toolkit-created shell block policies were removed. Restart or sign out/in to refresh every session.'
}

Export-ModuleMember -Function @(
    'Install-PRInputDrivers',
    'Get-PRLogPath',
    'Initialize-PRLog',
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
