# Win11 Pointer Recovery Toolkit

Developer: Kirtan Teg Singh
Website: www.sacred-geometry.uk

Win11 Pointer Recovery Toolkit is an open source PowerShell utility for Windows 11 shared/public computers where the mouse pointer disappears after a broken installer, corrupted driver, damaged cursor scheme, or bad touchpad/accessibility setting.

The tool runs from the keyboard, writes a detailed log, performs diagnostics, restores cursor and touchpad settings, restarts/reinstalls input devices, forces hardware detection, and can run DISM/SFC repairs. After recovery, it can optionally apply local policies that block common command shells for non-administrative use.

## Features

- Windows 11 build check at startup.
- Console interface usable without a mouse.
- Standard-user diagnostics and current-user repairs.
- Administrator elevation only for driver, hardware, system repair, and policy changes.
- Detailed log file in `%LOCALAPPDATA%\Win11PointerRecovery\Logs` or `%ProgramData%\Win11PointerRecovery\Logs` when elevated.
- Cursor scheme reset to Windows default Aero cursors.
- Cursor accessibility reset, including pointer size/color and mouse trails.
- Precision Touchpad setting reset.
- PnP input device restart and optional remove/rescan reinstall flow.
- Hardware rescan through `pnputil`.
- Advanced system repair through `DISM.exe` and `sfc.exe`.
- Optional local policy block for `cmd.exe`, Windows PowerShell, PowerShell 7, and Windows Terminal.
- Reversal workflow and manual rollback notes.

## Requirements

- Windows 11, build 22000 or later.
- Windows PowerShell 5.1 or PowerShell 7+.
- Administrator credentials for:
  - Restarting or reinstalling input devices.
  - Forcing hardware detection.
  - Running DISM/SFC.
  - Applying or reverting system tool blocks.

## Quick start

Open PowerShell from the keyboard and run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\src\Win11PointerRecovery.ps1
```

You can also run direct actions:

```powershell
.\src\Win11PointerRecovery.ps1 -Action Diagnose
.\src\Win11PointerRecovery.ps1 -Action AutoRecover
.\src\Win11PointerRecovery.ps1 -Action RepairSystem
```

For fully unattended advanced actions:

```powershell
.\src\Win11PointerRecovery.ps1 -Action AutoRecover -AcceptRisk -NoPause
```

`-AcceptRisk` allows the advanced automatic sequence to remove matching input devices and rescan them so Windows can reinstall drivers from the local driver store. Use it only when you are comfortable with that repair path.

## Menu options

1. Diagnose pointer, touchpad, driver, and policy anomalies.
2. Reset Windows cursor scheme and cursor accessibility settings.
3. Reset Precision Touchpad and touch input settings.
4. Restart touchpad/input devices.
5. Reinstall or refresh input drivers with the Windows driver store.
6. Force hardware detection.
7. Repair system files with DISM and SFC.
8. Automatic recovery sequence.
9. Apply optional system tool block after recovery.
10. Revert system tool block.

## What the diagnostic checks

- Windows 11 compatibility.
- Administrator status.
- Cursor registry values under `HKCU:\Control Panel\Cursors`.
- Missing cursor `.cur` or `.ani` files.
- Mouse trails and cursor accessibility values.
- Precision Touchpad user settings.
- PnP mouse/touchpad/HID device status.
- Signed input driver metadata.
- Pending reboot indicators.

## Optional system tool block

After pointer recovery, option 9 can apply local restrictions so standard users cannot launch common command shells from Windows Search, File Explorer, or normal application launch paths.

The block uses:

- Software Restriction Policies under `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers`.
- User shell policies under loaded non-admin `HKEY_USERS\<SID>` hives:
  - `Software\Policies\Microsoft\Windows\System\DisableCMD`
  - `Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun`

Blocked executables include:

- `cmd.exe`
- `powershell.exe`
- `powershell_ise.exe`
- `pwsh.exe`
- `wt.exe`
- `WindowsTerminal.exe`
- `OpenConsole.exe`

Important: this is a local shared-computer hardening feature, not a complete application control system. For managed fleets, test in a non-production account first and prefer enterprise controls such as AppLocker or WDAC when available.

## Reverting the system tool block

Preferred method:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\src\Win11PointerRecovery.ps1 -Action RevertSystemToolBlock
```

Manual administrator rollback:

1. Sign in with a local administrator account.
2. Open `regedit.exe` as administrator.
3. Delete toolkit-created rules whose `Description` starts with `Win11 Pointer Recovery Toolkit` under:

```text
HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers\0\Paths
```

4. For affected user hives under `HKEY_USERS\<SID>`, remove:

```text
Software\Policies\Microsoft\Windows\System\DisableCMD
Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun
Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun\*
```

5. Run `gpupdate /force` from an elevated administrator shell or restart Windows.

The tool also exports policy registry backups before applying the block. Backups are written next to the log file in a `PolicyBackup-*` folder.

## Project structure

```text
Win11PointerRecovery/
  README.md
  LICENSE
  src/
    Win11PointerRecovery.ps1
    Modules/
      PointerRecovery.Core/
        PointerRecovery.Core.psd1
        PointerRecovery.Core.psm1
```

## Safety notes

- Run diagnostics first.
- Keep the keyboard available before device restart/reinstall actions.
- Use driver remove/rescan only after cursor and settings recovery do not help.
- DISM/SFC can take a long time.
- Test the system tool block with a non-admin account before using it on a public computer.
- If policies behave unexpectedly, sign in as administrator, revert with the script or manual registry steps, then restart.

## References

- Microsoft Learn: [Software Restriction Policies Technical Overview](https://learn.microsoft.com/en-us/windows-server/identity/software-restriction-policies/software-restriction-policies-technical-overview)
- Microsoft Learn: [Work with Software Restriction Policies Rules](https://learn.microsoft.com/en-us/windows-server/identity/software-restriction-policies/work-with-software-restriction-policies-rules)
- Microsoft Learn: [ADMX Shell Command Prompt and RegEdit Tools Policy CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-shellcommandpromptregedittools)

## License

MIT License. See [LICENSE](LICENSE).
