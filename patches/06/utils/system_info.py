#!/usr/bin/env python3
"""
System information gathering for macOS Threat Detection & Response Framework (MTDRF)

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import os
import platform
import subprocess
import sys
from typing import Dict, Optional

def get_system_serial() -> Optional[str]:
    """
    Get system serial number for comparison with malware exfiltration patterns.
    
    Returns:
        System serial number or None if unavailable
    """
    try:
        result = subprocess.run(
            ['/usr/sbin/system_profiler', 'SPHardwareDataType'],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if 'Serial Number' in line or 'Serial Number (system)' in line:
                    # Extract serial number after colon
                    parts = line.split(':', 1)
                    if len(parts) == 2:
                        serial = parts[1].strip()
                        return serial
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        print(f"Warning: Could not retrieve system serial: {e}", file=sys.stderr)
    
    return None

def get_mac_version() -> Dict[str, str]:
    """
    Get macOS version information.
    
    Returns:
        Dictionary with macOS version details
    """
    version_info = {
        'system': platform.system(),
        'release': platform.release(),
        'version': platform.version(),
        'machine': platform.machine(),
        'processor': platform.processor(),
    }
    
    # Get macOS product version
    try:
        result = subprocess.run(
            ['sw_vers'],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if 'ProductName:' in line:
                    version_info['product_name'] = line.split(':', 1)[1].strip()
                elif 'ProductVersion:' in line:
                    version_info['product_version'] = line.split(':', 1)[1].strip()
                elif 'BuildVersion:' in line:
                    version_info['build_version'] = line.split(':', 1)[1].strip()
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    
    return version_info

def get_user_info() -> Dict[str, str]:
    """
    Get current user information.
    
    Returns:
        Dictionary with user information
    """
    return {
        'username': os.getenv('USER', 'unknown'),
        'home': os.path.expanduser('~'),
        'uid': os.getuid(),
        'gid': os.getgid(),
        'groups': subprocess.run(
            ['groups'],
            capture_output=True,
            text=True,
            timeout=5
        ).stdout.strip().split() if subprocess.run(['groups'], capture_output=True).returncode == 0 else [],
    }

def get_system_info() -> Dict:
    """
    Get comprehensive system information.
    
    Returns:
        Dictionary with all system information
    """
    return {
        'serial': get_system_serial(),
        'mac_version': get_mac_version(),
        'user': get_user_info(),
        'python_version': sys.version,
        'platform': platform.platform(),
    }
