#!/usr/bin/env python3
"""
Keychain monitor for detecting unauthorized Keychain API calls, especially Chrome encryption key retrieval.

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional

sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.output import print_debug, print_info, print_warning, print_error


def monitor_keychain_access() -> List[Dict[str, any]]:
    """
    Monitor for Keychain access, specifically SecItemCopyMatching calls.
    Note: This requires system log analysis as direct Keychain monitoring is restricted.
    
    Returns:
        List of detected Keychain access events
    """
    events = []
    
    # Check unified logs for Keychain access
    try:
        # Search for security framework calls in logs
        result = subprocess.run(
            ['log', 'show', '--predicate', 'subsystem == "com.apple.security"', '--last', '1h', '--style', 'syslog'],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            log_output = result.stdout.lower()
            
            # Look for SecItemCopyMatching calls
            if 'secitemcopymatching' in log_output or 'secitemcopy' in log_output:
                events.append({
                    'event_type': 'keychain_access',
                    'severity': 'medium',
                    'description': 'Keychain access detected in system logs',
                    'note': 'SecItemCopyMatching calls found - may indicate credential extraction',
                })
            
            # Look for Chrome Safe Storage specifically
            if 'chrome safe storage' in log_output:
                events.append({
                    'event_type': 'chrome_keychain_access',
                    'severity': 'high',
                    'description': 'Chrome Safe Storage Keychain access detected',
                    'note': 'This may indicate extraction of Chrome encryption key',
                })
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        print_debug(f"Error monitoring Keychain access: {e}")
    
    return events

def check_chrome_keychain() -> Dict[str, any]:
    """
    Specifically check for Chrome Safe Storage Keychain access.
    
    Returns:
        Dictionary with Chrome Keychain status
    """
    result = {
        'chrome_keychain_item': 'Chrome Safe Storage',
        'accessible': False,
        'severity': 'high',
    }
    
    try:
        # Try to query the Keychain item (this may prompt for user approval)
        # Note: This is a simplified check - actual monitoring requires more sophisticated methods
        security_result = subprocess.run(
            ['security', 'find-generic-password', '-s', 'Chrome Safe Storage', '-a', 'Chrome'],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if security_result.returncode == 0:
            result['accessible'] = True
            result['note'] = 'Chrome Safe Storage Keychain item exists and is accessible'
        else:
            result['accessible'] = False
            result['note'] = 'Chrome Safe Storage Keychain item not found or not accessible'
            result['error'] = security_result.stderr
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        result['error'] = str(e)
        result['note'] = 'Error checking Chrome Keychain - may require user interaction'
        print_debug(f"Error checking Chrome Keychain: {e}")
    
    return result

def parse_keychain_logs() -> List[Dict[str, any]]:
    """
    Parse security logs for Keychain-related activity.
    
    Returns:
        List of Keychain access events
    """
    events = []
    
    try:
        # Parse unified logs with security predicate
        result = subprocess.run(
            ['log', 'show', '--predicate', 
             'eventMessage CONTAINS "keychain" OR eventMessage CONTAINS "SecItem" OR eventMessage CONTAINS "security"',
             '--last', '2h', '--style', 'compact'],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            lines = result.stdout.splitlines()
            
            for line in lines:
                line_lower = line.lower()
                
                # Look for suspicious patterns
                if 'secitemcopymatching' in line_lower:
                    events.append({
                        'event_type': 'keychain_query',
                        'severity': 'medium',
                        'log_line': line,
                        'description': 'SecItemCopyMatching call detected',
                    })
                
                if 'chrome' in line_lower and 'safe storage' in line_lower:
                    events.append({
                        'event_type': 'chrome_keychain_access',
                        'severity': 'high',
                        'log_line': line,
                        'description': 'Chrome Safe Storage Keychain access detected',
                    })
                
                if 'generic password' in line_lower and 'chrome' in line_lower:
                    events.append({
                        'event_type': 'chrome_password_access',
                        'severity': 'high',
                        'log_line': line,
                        'description': 'Chrome password Keychain access detected',
                    })
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        print_debug(f"Error parsing Keychain logs: {e}")
    
    return events

def get_keychain_access_summary() -> Dict[str, any]:
    """
    Get summary of Keychain access monitoring results.
    
    Returns:
        Summary dictionary
    """
    chrome_check = check_chrome_keychain()
    keychain_events = monitor_keychain_access()
    log_events = parse_keychain_logs()
    
    return {
        'chrome_keychain': chrome_check,
        'keychain_events': keychain_events,
        'log_events': log_events,
        'total_events': len(keychain_events) + len(log_events),
        'high_severity_count': sum(1 for e in keychain_events + log_events if e.get('severity') == 'high'),
    }
