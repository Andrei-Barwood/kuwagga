#!/usr/bin/env python3
"""
macOS Threat Detection & Response Framework (MTDRF)
Main CLI orchestrator

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import sys
from pathlib import Path

# Ensure we can import our modules
sys.path.insert(0, str(Path(__file__).parent))

import click
from datetime import datetime

import config
from utils.output import (
    print_header, print_info, print_warning, print_error, print_success,
    print_json, format_report, progress_bar
)
from utils.permissions import check_admin_privileges, get_capabilities
from utils.system_info import get_system_info

# Import detectors
from detectors import binary_analyzer, process_monitor, file_monitor, keychain_monitor, network_monitor

# Import preventers
from preventers import file_protection, network_firewall, keychain_protection

# Import mitigators
from mitigators import quarantine, cleanup, recovery

# Import forensic tools
from forensic import binary_forensics, process_analyzer, log_analyzer


@click.group()
@click.option('--json', 'output_json', is_flag=True, help='Output in JSON format')
@click.option('--verbose', '-v', is_flag=True, help='Enable verbose output')
@click.option('--no-color', is_flag=True, help='Disable colored output')
@click.option('--output', '-o', type=click.Path(), help='Write output to file')
@click.pass_context
def cli(ctx, output_json, verbose, no_color, output):
    """macOS Threat Detection & Response Framework (MTDRF)"""
    # Ensure context object exists
    ctx.ensure_object(dict)
    
    # Update config based on CLI options
    config.update_config('verbose', verbose)
    config.update_config('output_format', 'json' if output_json else 'cli')
    config.update_config('no_color', no_color)
    if output:
        config.update_config('output_file', output)
    
    # Show banner
    if not output_json:
        print_header("macOS Threat Detection & Response Framework (MTDRF)", 
                    color="#A6A4D7")
        print_info(f"Started: {datetime.now().isoformat()}")
        
        # Show capabilities
        capabilities = get_capabilities()
        if capabilities.get('admin_privileges'):
            print_success("Running with administrator privileges")
        else:
            print_warning("Running without administrator privileges - some features may be limited")
            print_info("Use 'sudo' for full functionality")


@cli.command()
@click.option('--recursive/--no-recursive', default=True, help='Scan directories recursively')
@click.argument('directory', type=click.Path(exists=True, file_okay=False, dir_okay=True))
def scan(directory, recursive):
    """Scan directory for suspicious binaries"""
    print_header(f"Scanning Directory: {directory}")
    
    dir_path = Path(directory)
    results = binary_analyzer.scan_directory(dir_path, recursive=recursive)
    
    if config.OUTPUT_CONFIG.get('format') == 'json':
        print_json({'scan_results': results})
    else:
        if results:
            print_warning(f"Found {len(results)} suspicious binaries:")
            for result in results:
                print_info(f"  - {result['file_path']}")
                print_info(f"    Severity: {result['severity']}")
                print_info(f"    Indicators: {result['indicator_count']}")
        else:
            print_success("No suspicious binaries found")


@cli.command()
def detect():
    """Run all detection modules"""
    print_header("Running Detection Modules")
    
    all_results = {
        'timestamp': datetime.now().isoformat(),
        'binary_analysis': [],
        'process_monitoring': [],
        'file_monitoring': [],
        'keychain_monitoring': {},
        'network_monitoring': {},
    }
    
    # Binary analysis
    print_info("Running binary analyzer...")
    # This would scan common locations - for now, just show status
    print_info("Binary analyzer ready (use 'scan' command to analyze specific directories)")
    
    # Process monitoring
    print_info("Running process monitor...")
    suspicious_processes = process_monitor.detect_suspicious_patterns()
    all_results['process_monitoring'] = suspicious_processes
    if suspicious_processes:
        print_warning(f"Found {len(suspicious_processes)} suspicious processes")
    else:
        print_success("No suspicious processes detected")
    
    # File monitoring
    print_info("Monitoring sensitive files...")
    chrome_events = file_monitor.monitor_chrome_files()
    exodus_events = file_monitor.monitor_exodus_wallet()
    wallet_files = file_monitor.monitor_crypto_wallets()
    all_results['file_monitoring'] = {
        'chrome': chrome_events,
        'exodus': exodus_events,
        'wallets': wallet_files,
    }
    print_info(f"Monitored {len(chrome_events) + len(exodus_events)} file locations")
    
    # Keychain monitoring
    print_info("Monitoring Keychain access...")
    keychain_summary = keychain_monitor.get_keychain_access_summary()
    all_results['keychain_monitoring'] = keychain_summary
    if keychain_summary.get('high_severity_count', 0) > 0:
        print_warning(f"Found {keychain_summary['high_severity_count']} high-severity Keychain events")
    else:
        print_success("No suspicious Keychain activity detected")
    
    # Network monitoring
    print_info("Monitoring network activity...")
    network_analysis = network_monitor.analyze_network_activity()
    all_results['network_monitoring'] = network_analysis
    if network_analysis.get('high_severity_count', 0) > 0:
        print_warning(f"Found {network_analysis['high_severity_count']} high-severity network connections")
        for conn in network_analysis.get('localhost_8000_connections', []):
            print_warning(f"  - {conn.get('connection', 'Unknown')}")
    else:
        print_success("No suspicious network activity detected")
    
    # Output results
    if config.OUTPUT_CONFIG.get('format') == 'json':
        print_json(all_results)
    else:
        print_header("Detection Summary")
        total_threats = (
            len(suspicious_processes) +
            network_analysis.get('high_severity_count', 0) +
            keychain_summary.get('high_severity_count', 0)
        )
        if total_threats > 0:
            print_warning(f"Total threats detected: {total_threats}")
            print_info("Run 'mtdrf mitigate' to quarantine and clean detected threats")
        else:
            print_success("No threats detected")


@cli.command()
def prevent():
    """Apply prevention measures"""
    print_header("Applying Prevention Measures")
    
    if not check_admin_privileges():
        print_warning("Some prevention measures require administrator privileges")
    
    # File protection
    print_info("Protecting sensitive files...")
    protection_results = file_protection.protect_sensitive_files()
    print_info(f"Protected {len(protection_results.get('protected', []))} files")
    
    # Network firewall (requires admin)
    print_info("Checking firewall status...")
    firewall_status = network_firewall.get_firewall_status()
    if firewall_status.get('enabled'):
        print_success("Firewall is enabled")
    else:
        print_warning("Firewall is not enabled - enable in System Preferences > Security")
    
    # Keychain protection
    print_info("Checking Keychain protection...")
    keychain_status = keychain_protection.get_keychain_protection_status()
    print_info("Keychain access is controlled by macOS TCC")
    print_info("Review Keychain Access app for Chrome Safe Storage protection")
    
    print_success("Prevention measures review complete")


@cli.command()
@click.option('--auto', is_flag=True, help='Automatically quarantine without confirmation')
def mitigate(auto):
    """Run mitigation procedures"""
    print_header("Running Mitigation Procedures")
    
    if not auto:
        print_warning("Mitigation will quarantine detected threats")
        if not click.confirm("Continue?"):
            print_info("Mitigation cancelled")
            return
    
    # First, detect threats
    print_info("Detecting threats...")
    suspicious_processes = process_monitor.detect_suspicious_patterns()
    network_analysis = network_monitor.analyze_network_activity()
    
    # Quarantine suspicious binaries (would need paths from detection)
    print_info("Quarantine functionality available - use 'scan' to identify files first")
    
    # Generate recovery checklist
    print_info("Generating recovery checklist...")
    checklist = recovery.change_all_passwords()
    
    print_success("Mitigation procedures complete")
    print_info("Review the password change checklist above")


@cli.command()
@click.argument('binary_path', type=click.Path(exists=True, dir_okay=False))
def forensic(binary_path):
    """Perform forensic analysis on a binary"""
    print_header(f"Forensic Analysis: {binary_path}")
    
    binary = Path(binary_path)
    report = binary_forensics.generate_forensic_report(binary)
    
    if config.OUTPUT_CONFIG.get('format') == 'json':
        print_json(report)
    else:
        print_info(f"File: {report.get('file_path')}")
        print_info(f"Severity: {report.get('severity', 'unknown')}")
        
        sig_analysis = report.get('signature_analysis', {})
        if sig_analysis.get('is_suspicious'):
            print_warning("Suspicious signature detected")
            print_info(f"  Signature Type: {sig_analysis.get('signature_type', 'unknown')}")
            print_info(f"  Team ID: {sig_analysis.get('team_identifier', 'not set')}")
        
        indicators = report.get('strings_analysis', {}).get('indicators', {})
        total_indicators = sum(len(v) for v in indicators.values())
        if total_indicators > 0:
            print_warning(f"Found {total_indicators} stealer malware indicators")
            for category, items in indicators.items():
                if items:
                    print_info(f"  {category}: {len(items)} indicators")
        
        recommendations = report.get('recommendations', [])
        if recommendations:
            print_header("Recommendations")
            for rec in recommendations:
                print_info(f"  - {rec}")


@cli.command()
def monitor():
    """Continuous monitoring mode"""
    print_header("Continuous Monitoring Mode")
    print_info("Monitoring for threats... (Press Ctrl+C to stop)")
    
    try:
        import time
        interval = config.DETECTION_THRESHOLDS.get('process_monitor_interval', 5)
        
        while True:
            # Run detection
            suspicious = process_monitor.detect_suspicious_patterns()
            network = network_monitor.monitor_localhost_8000()
            
            if suspicious or network:
                print_warning(f"Threats detected at {datetime.now().isoformat()}")
                if suspicious:
                    print_warning(f"  Suspicious processes: {len(suspicious)}")
                if network:
                    print_warning(f"  Suspicious network connections: {len(network)}")
            
            time.sleep(interval)
    except KeyboardInterrupt:
        print_info("\nMonitoring stopped")


@cli.command()
@click.option('--hours', default=24, help='Number of hours to analyze')
def report(hours):
    """Generate comprehensive detection report"""
    print_header("Generating Comprehensive Report")
    
    report_data = {
        'timestamp': datetime.now().isoformat(),
        'system_info': get_system_info(),
        'capabilities': get_capabilities(),
        'detection_results': {},
        'timeline': {},
    }
    
    # Run all detections
    print_info("Running detection modules...")
    suspicious_processes = process_monitor.detect_suspicious_patterns()
    network_analysis = network_monitor.analyze_network_activity()
    keychain_summary = keychain_monitor.get_keychain_access_summary()
    
    report_data['detection_results'] = {
        'processes': suspicious_processes,
        'network': network_analysis,
        'keychain': keychain_summary,
    }
    
    # Generate timeline
    print_info(f"Analyzing logs for last {hours} hours...")
    timeline = log_analyzer.timeline_analysis(hours=hours)
    report_data['timeline'] = timeline
    
    # Output
    if config.OUTPUT_CONFIG.get('format') == 'json':
        print_json(report_data)
    else:
        print_header("MTDRF Comprehensive Report")
        print_info(f"Generated: {report_data['timestamp']}")
        print_info(f"System: {report_data['system_info'].get('mac_version', {}).get('product_name', 'Unknown')}")
        print_info(f"Capabilities: {'Admin' if report_data['capabilities'].get('admin_privileges') else 'User-level'}")
        
        # Summary
        total_threats = (
            len(suspicious_processes) +
            network_analysis.get('high_severity_count', 0) +
            keychain_summary.get('high_severity_count', 0)
        )
        
        if total_threats > 0:
            print_warning(f"Total threats detected: {total_threats}")
        else:
            print_success("No threats detected")
        
        # Timeline summary
        timeline_events = sum(len(events) for events in timeline.values())
        print_info(f"Timeline events: {timeline_events}")


if __name__ == '__main__':
    cli()
