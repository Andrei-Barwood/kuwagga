#!/usr/bin/env python3
"""
Log analyzer for parsing system logs for stealer malware indicators and suspicious activity.

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import subprocess
import sys
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional

sys.path.insert(0, str(Path(__file__).parent.parent))
import config
from utils.output import print_debug, print_info, print_warning


def parse_unified_logs(hours: int = 1, predicate: Optional[str] = None) -> List[str]:
    """
    Parse unified logs using log show command.
    
    Args:
        hours: Number of hours to look back
        predicate: Optional predicate for filtering
        
    Returns:
        List of log lines
    """
    log_lines = []
    
    try:
        cmd = ['log', 'show', '--last', f'{hours}h', '--style', 'syslog']
        
        if predicate:
            cmd.extend(['--predicate', predicate])
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode == 0:
            log_lines = result.stdout.splitlines()
        else:
            print_warning(f"Error parsing unified logs: {result.stderr}")
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        print_debug(f"Error accessing unified logs: {e}")
    
    return log_lines

def search_for_stealer_indicators(hours: int = 2) -> List[Dict[str, any]]:
    """
    Search logs for known stealer malware patterns.
    
    Args:
        hours: Number of hours to search back
        
    Returns:
        List of detected indicators
    """
    indicators = []
    
    # Get all logs
    log_lines = parse_unified_logs(hours=hours)
    
    # Search for indicators from config
    for line in log_lines:
        line_lower = line.lower()
        matched_indicators = []
        
        for indicator in config.STEALER_INDICATORS:
            if indicator.lower() in line_lower:
                matched_indicators.append(indicator)
        
        if matched_indicators:
            indicators.append({
                'log_line': line,
                'matched_indicators': matched_indicators,
                'severity': 'high' if len(matched_indicators) >= 2 else 'medium',
            })
    
    return indicators

def search_for_ad_hoc_signature_activity(hours: int = 2) -> List[Dict[str, any]]:
    """
    Detect ad-hoc signature-related activity in logs.
    
    Args:
        hours: Number of hours to search back
        
    Returns:
        List of detected signature-related events
    """
    events = []
    
    # Search for codesign activity
    predicate = 'eventMessage CONTAINS "codesign" OR eventMessage CONTAINS "signature"'
    log_lines = parse_unified_logs(hours=hours, predicate=predicate)
    
    for line in log_lines:
        line_lower = line.lower()
        
        if 'adhoc' in line_lower or 'ad-hoc' in line_lower:
            events.append({
                'log_line': line,
                'event_type': 'ad_hoc_signature',
                'severity': 'medium',
            })
        
        if 'linker-signed' in line_lower:
            events.append({
                'log_line': line,
                'event_type': 'linker_signed',
                'severity': 'low',
            })
    
    return events

def timeline_analysis(hours: int = 24) -> Dict[str, List[Dict[str, any]]]:
    """
    Build timeline of suspicious activity from logs.
    
    Args:
        hours: Number of hours to analyze
        
    Returns:
        Dictionary with timeline events organized by type
    """
    timeline = {
        'stealer_indicators': [],
        'signature_activity': [],
        'file_access': [],
        'network_activity': [],
    }
    
    # Search for stealer indicators
    timeline['stealer_indicators'] = search_for_stealer_indicators(hours=hours)
    
    # Search for signature activity
    timeline['signature_activity'] = search_for_ad_hoc_signature_activity(hours=hours)
    
    # Search for file access (simplified)
    file_access_logs = parse_unified_logs(
        hours=hours,
        predicate='eventMessage CONTAINS "Chrome" OR eventMessage CONTAINS "Exodus"'
    )
    
    for line in file_access_logs:
        line_lower = line.lower()
        if any(path_keyword in line_lower for path_keyword in ['cookie', 'login data', 'exodus.wallet']):
            timeline['file_access'].append({
                'log_line': line,
                'severity': 'medium',
            })
    
    # Search for network activity
    network_logs = parse_unified_logs(
        hours=hours,
        predicate='subsystem == "com.apple.network"'
    )
    
    for line in network_logs:
        line_lower = line.lower()
        if 'localhost:8000' in line_lower or '127.0.0.1:8000' in line_lower:
            timeline['network_activity'].append({
                'log_line': line,
                'severity': 'high',
            })
    
    # Sort events by timestamp (simplified - would parse timestamps properly)
    for category in timeline:
        timeline[category].sort(key=lambda x: x.get('log_line', ''))
    
    return timeline

def generate_timeline_report(hours: int = 24) -> str:
    """
    Generate a human-readable timeline report.
    
    Args:
        hours: Number of hours to analyze
        
    Returns:
        Formatted timeline report string
    """
    timeline = timeline_analysis(hours=hours)
    
    report_lines = [
        f"MTDRF Timeline Analysis Report",
        f"{'='*60}",
        f"Analysis Period: Last {hours} hours",
        f"Generated: {datetime.now().isoformat()}",
        f"",
    ]
    
    for category, events in timeline.items():
        if events:
            report_lines.append(f"\n{category.upper().replace('_', ' ')} ({len(events)} events):")
            report_lines.append("-" * 60)
            for event in events[:20]:  # Limit to first 20 events per category
                log_line = event.get('log_line', 'N/A')
                severity = event.get('severity', 'unknown')
                report_lines.append(f"  [{severity.upper()}] {log_line[:80]}...")
    
    return "\n".join(report_lines)
