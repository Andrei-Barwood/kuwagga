# macOS Threat Detection & Response Framework (MTDRF)

A comprehensive Python3 security framework for detection, prevention, mitigation, and forensic analysis of macOS stealer malware and ad-hoc signed threats. Designed for security researchers and incident response teams.

## Features

- **Modular Architecture**: Independent modules for focused analysis
- **Multiple Detection Methods**: Binary analysis, process monitoring, file access monitoring, Keychain monitoring, network monitoring
- **Prevention Capabilities**: File protection, network firewall rules, Keychain protection
- **Mitigation Tools**: Quarantine, cleanup, and recovery procedures
- **Forensic Analysis**: Deep binary analysis, process tree analysis, log analysis
- **Dual Mode**: User-level and admin-level operation with graceful degradation
- **Multiple Output Formats**: CLI with custom color palette and JSON output

## Installation

```bash
cd /Users/kirtantegsingh/Public/tools/kuwagga/patches/06
pip3 install -r requirements.txt
```

## Usage

### Basic Detection
```bash
python3 mtdrf.py detect
```

### Scan Directory
```bash
python3 mtdrf.py scan /path/to/directory
```

### Forensic Analysis
```bash
python3 mtdrf.py forensic /path/to/suspicious/binary
```

### Continuous Monitoring
```bash
python3 mtdrf.py monitor
```

### Generate Report
```bash
python3 mtdrf.py report --output report.json
```

### Apply Prevention Measures
```bash
python3 mtdrf.py prevent
```

### Run Mitigation Procedures
```bash
python3 mtdrf.py mitigate
```

## Command Line Options

- `--json`: Output results in JSON format
- `--verbose`: Enable verbose/debug output
- `--no-color`: Disable colored output
- `--output FILE`: Write output to file

## Modules

### Detectors
- `binary_analyzer.py`: Detects ad-hoc signed binaries and suspicious signing patterns
- `process_monitor.py`: Monitors system_profiler and suspicious processes
- `file_monitor.py`: Monitors access to sensitive files (Chrome, Exodus, etc.)
- `keychain_monitor.py`: Monitors Keychain API calls
- `network_monitor.py`: Monitors network connections and exfiltration patterns

### Preventers
- `file_protection.py`: Hardens file access to sensitive locations
- `network_firewall.py`: Creates firewall rules to block suspicious activity
- `keychain_protection.py`: Protects Keychain access

### Mitigators
- `quarantine.py`: Quarantines detected malware
- `cleanup.py`: Cleans up after infection
- `recovery.py`: Recovery procedures and password change checklists

### Forensic Tools
- `binary_forensics.py`: Deep binary analysis
- `process_analyzer.py`: Process tree and memory analysis
- `log_analyzer.py`: System log analysis and timeline creation

## Threat Model

This framework detects:
1. Ad-hoc signed binaries
2. Credential stealing attempts
3. Cryptocurrency wallet theft
4. System profiling for hardware identifiers
5. Keychain exfiltration
6. Network exfiltration patterns
7. Process behavior anomalies

## Security Considerations

- **Read-only by default**: All detection operations are non-destructive
- **Explicit confirmation**: Destructive operations require user confirmation
- **Quarantine before deletion**: Detected threats are quarantined first
- **Backup creation**: System modifications require backups
- **Audit trail**: All actions are logged with timestamps
- **Permission-aware**: Operates within available permissions

## Requirements

- Python 3.6+
- macOS (uses native macOS tools and APIs)
- Admin privileges (optional, for enhanced capabilities)

## Author

ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ

## License

This tool is provided for security research and incident response purposes.

**Owner**: Snocomm. - 2026

## Disclaimer

This tool is designed for authorized security research and incident response. Always ensure you have proper authorization before running security analysis tools on systems.
