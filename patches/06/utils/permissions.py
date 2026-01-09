#!/usr/bin/env python3
"""
Permission detection and management for macOS Threat Detection & Response Framework (MTDRF)

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import os
import subprocess
import sys
from typing import Dict, List, Optional

def check_admin_privileges() -> bool:
    """
    Check if the current process is running with administrator privileges.
    
    Returns:
        True if running as admin, False otherwise
    """
    if os.geteuid() == 0:
        return True
    
    # On macOS, check if user is in admin group
    try:
        result = subprocess.run(
            ['groups'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            groups = result.stdout.strip().split()
            return 'admin' in groups or 'wheel' in groups
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    
    return False

def request_admin_if_needed(operation: str) -> bool:
    """
    Request admin privileges if needed for an operation.
    Note: This is a placeholder - actual elevation requires GUI or sudo.
    
    Args:
        operation: Description of the operation requiring admin
        
    Returns:
        True if admin privileges are available, False otherwise
    """
    if check_admin_privileges():
        return True
    
    print(f"Warning: Operation '{operation}' requires administrator privileges.", file=sys.stderr)
    print("Please run with sudo or ensure you have admin rights.", file=sys.stderr)
    return False

def get_capabilities() -> Dict[str, bool]:
    """
    Get list of available capabilities based on current permissions.
    
    Returns:
        Dictionary mapping capability names to availability (True/False)
    """
    is_admin = check_admin_privileges()
    
    capabilities = {
        'admin_privileges': is_admin,
        'read_system_logs': is_admin,  # System logs require admin
        'firewall_rules': is_admin,  # Firewall requires admin
        'tcc_protection': is_admin,  # TCC requires admin
        'file_monitoring': True,  # User-level file monitoring possible
        'process_monitoring': True,  # User-level process monitoring possible
        'network_monitoring': True,  # User-level network monitoring possible
        'binary_analysis': True,  # Binary analysis doesn't require special privileges
        'quarantine': True,  # Quarantine in user directory
        'keychain_read': False,  # Keychain access requires user approval
        'system_profiler_monitor': True,  # Can monitor via process watching
    }
    
    # Check if keychain access might be available (requires user interaction)
    # This is a best-effort check
    try:
        # Try to access security framework (will prompt user if needed)
        import Security
        capabilities['keychain_framework_available'] = True
    except ImportError:
        capabilities['keychain_framework_available'] = False
    
    return capabilities

def get_effective_permissions() -> Dict[str, str]:
    """
    Get effective permission level and limitations.
    
    Returns:
        Dictionary with permission information
    """
    is_admin = check_admin_privileges()
    caps = get_capabilities()
    
    return {
        'user': os.getenv('USER', 'unknown'),
        'euid': os.geteuid(),
        'is_admin': is_admin,
        'capabilities': caps,
        'limitations': [
            cap for cap, available in caps.items() if not available
        ],
    }
