#!/usr/bin/env python3
"""
File monitor for detecting access to sensitive files commonly targeted by stealer malware.

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional

import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

import config
from utils.output import print_debug, print_info, print_warning


def monitor_chrome_files() -> List[Dict[str, any]]:
    """
    Monitor Chrome credential files for suspicious access.
    
    Returns:
        List of detected access events
    """
    events = []
    chrome_paths = config.SENSITIVE_PATHS.get('chrome', [])
    
    for file_path in chrome_paths:
        path = Path(file_path)
        if path.exists():
            # Check file access time
            try:
                stat = path.stat()
                # In a real implementation, we would use fsevents or similar
                # to monitor real-time access. Here we check file metadata.
                
                # Check if file was recently accessed
                # This is a simplified check - real monitoring requires FSEvents
                events.append({
                    'file_path': str(path),
                    'exists': True,
                    'size': stat.st_size,
                    'modified': stat.st_mtime,
                    'accessed': stat.st_atime,
                    'note': 'File exists - real-time monitoring requires FSEvents or log analysis',
                })
            except OSError as e:
                print_debug(f"Error checking Chrome file {path}: {e}")
        else:
            # File doesn't exist - log for information
            events.append({
                'file_path': str(path),
                'exists': False,
                'note': 'File not found (may have been deleted or not created yet)',
            })
    
    return events

def monitor_exodus_wallet() -> List[Dict[str, any]]:
    """
    Monitor Exodus wallet files for suspicious access.
    
    Returns:
        List of detected access events
    """
    events = []
    exodus_paths = config.SENSITIVE_PATHS.get('exodus', [])
    
    for file_path in exodus_paths:
        path = Path(file_path)
        if path.exists():
            try:
                stat = path.stat()
                events.append({
                    'file_path': str(path),
                    'exists': True,
                    'size': stat.st_size,
                    'modified': stat.st_mtime,
                    'accessed': stat.st_atime,
                    'severity': 'high',
                    'note': 'Exodus wallet file exists - should be monitored for unauthorized access',
                })
            except OSError as e:
                print_debug(f"Error checking Exodus file {path}: {e}")
        else:
            events.append({
                'file_path': str(path),
                'exists': False,
                'note': 'Exodus wallet file not found',
            })
    
    return events

def monitor_crypto_wallets() -> List[Dict[str, any]]:
    """
    Monitor common cryptocurrency wallet locations.
    
    Returns:
        List of detected wallet files
    """
    all_wallets = []
    
    for wallet_type, paths in config.SENSITIVE_PATHS.items():
        if wallet_type in ['exodus', 'electrum', 'other_wallets']:
            for file_path in paths:
                path = Path(file_path)
                if path.exists():
                    if path.is_file():
                        try:
                            stat = path.stat()
                            all_wallets.append({
                                'wallet_type': wallet_type,
                                'file_path': str(path),
                                'size': stat.st_size,
                                'modified': stat.st_mtime,
                                'severity': 'high',
                            })
                        except OSError:
                            pass
                    elif path.is_dir():
                        # Check for wallet files in directory
                        for wallet_file in path.rglob('*'):
                            if wallet_file.is_file() and wallet_file.suffix in ['.json', '.dat', '.wallet', '.seco']:
                                try:
                                    stat = wallet_file.stat()
                                    all_wallets.append({
                                        'wallet_type': wallet_type,
                                        'file_path': str(wallet_file),
                                        'size': stat.st_size,
                                        'modified': stat.st_mtime,
                                        'severity': 'high',
                                    })
                                except OSError:
                                    pass
    
    return all_wallets

def use_fsevents() -> bool:
    """
    Check if FSEvents monitoring is available (requires macOS and permissions).
    
    Returns:
        True if FSEvents can be used
    """
    try:
        from CoreServices import FSEventStreamCreate, FSEventStreamStart, CFRunLoopRun
        return True
    except ImportError:
        print_debug("FSEvents not available - requires pyobjc-framework-CoreServices")
        return False

def check_file_access_logs() -> List[Dict[str, any]]:
    """
    Parse system logs for file access events.
    Note: This is a simplified version. Real implementation would use unified logging.
    
    Returns:
        List of file access events from logs
    """
    events = []
    
    # Check unified logs for file access
    try:
        # This is a simplified check - real implementation would parse unified logs
        # using 'log show' command with proper filters
        result = subprocess.run(
            ['log', 'show', '--predicate', 'subsystem == "com.apple.kernel"', '--last', '1h', '--style', 'syslog'],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            # Search for sensitive file paths in logs
            log_output = result.stdout
            for wallet_type, paths in config.SENSITIVE_PATHS.items():
                for file_path in paths:
                    if file_path in log_output:
                        events.append({
                            'file_path': file_path,
                            'wallet_type': wallet_type,
                            'found_in_logs': True,
                            'severity': 'medium',
                            'note': 'File path found in system logs - may indicate access',
                        })
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        print_debug(f"Error checking file access logs: {e}")
    
    return events
