#!/usr/bin/env python3
"""
Network firewall module for blocking suspicious network activity.

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional

sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.output import print_info, print_warning, print_error, print_success
from utils.permissions import check_admin_privileges


def block_localhost_8000() -> bool:
    """
    Block connections to localhost:8000 using pfctl (requires admin).
    
    Returns:
        True if successful
    """
    if not check_admin_privileges():
        print_error("Blocking network connections requires administrator privileges")
        return False
    
    print_warning("Network firewall rules require pfctl configuration")
    print_info("This feature requires manual pfctl rule configuration")
    print_info("Example: sudo pfctl -f /etc/pf.conf")
    
    # Note: Actual implementation would:
    # 1. Create pfctl rules file
    # 2. Add rule to block localhost:8000
    # 3. Apply rules with pfctl
    
    return False

def create_firewall_rule(rule_description: str, rule_config: str) -> bool:
    """
    Create generic firewall rule.
    
    Args:
        rule_description: Description of the rule
        rule_config: pfctl rule configuration
        
    Returns:
        True if successful
    """
    if not check_admin_privileges():
        print_error("Creating firewall rules requires administrator privileges")
        return False
    
    print_info(f"Firewall rule: {rule_description}")
    print_info("Firewall rule configuration requires manual setup")
    print_info("Rule config would be:")
    print_info(rule_config)
    
    return False

def monitor_blocked_attempts() -> List[Dict[str, any]]:
    """
    Monitor and log blocked connection attempts.
    
    Returns:
        List of blocked connection attempts
    """
    blocked = []
    
    # This would typically read from firewall logs
    # For macOS, this might involve pfctl logs or system logs
    
    try:
        result = subprocess.run(
            ['log', 'show', '--predicate', 'subsystem == "com.apple.network"', '--last', '1h'],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            # Parse logs for blocked connections
            for line in result.stdout.splitlines():
                if 'block' in line.lower() or 'deny' in line.lower():
                    blocked.append({
                        'log_line': line,
                        'timestamp': 'parsed_from_log',
                    })
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        print_warning(f"Error monitoring blocked attempts: {e}")
    
    return blocked

def get_firewall_status() -> Dict[str, any]:
    """
    Get current firewall status and rules.
    
    Returns:
        Dictionary with firewall status
    """
    status = {
        'enabled': False,
        'rules': [],
        'admin_available': check_admin_privileges(),
    }
    
    # Check if firewall is enabled (macOS)
    try:
        result = subprocess.run(
            ['/usr/libexec/ApplicationFirewall/socketfilterfw', '--getglobalstate'],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            output = result.stdout.lower()
            status['enabled'] = 'enabled' in output
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    
    return status
