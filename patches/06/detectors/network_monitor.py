#!/usr/bin/env python3
"""
Network monitor for detecting suspicious network exfiltration patterns, especially localhost:8000.

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.output import print_debug, print_info, print_warning


def check_active_connections() -> List[Dict[str, any]]:
    """
    Check active network connections using netstat or lsof.
    
    Returns:
        List of active connections
    """
    connections = []
    
    # Try lsof first (more detailed on macOS)
    try:
        result = subprocess.run(
            ['lsof', '-i', '-P', '-n'],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            lines = result.stdout.splitlines()[1:]  # Skip header
            for line in lines:
                parts = line.split()
                if len(parts) >= 9:
                    try:
                        # Parse lsof output: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
                        command = parts[0]
                        pid = parts[1]
                        user = parts[2]
                        name = parts[-1]  # Connection info (host:port)
                        
                        if ':' in name and '->' in name:
                            # Parse connection: localhost:port->remote:port
                            conn_info = {
                                'command': command,
                                'pid': pid,
                                'user': user,
                                'connection': name,
                                'local': None,
                                'remote': None,
                            }
                            
                            # Extract local and remote
                            if '->' in name:
                                local, remote = name.split('->', 1)
                                conn_info['local'] = local.strip()
                                conn_info['remote'] = remote.strip()
                            
                            connections.append(conn_info)
                    except (ValueError, IndexError):
                        continue
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        print_debug(f"Error using lsof: {e}")
        
        # Fallback to netstat
        try:
            result = subprocess.run(
                ['netstat', '-anv'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                # Parse netstat output (simplified)
                for line in result.stdout.splitlines():
                    if 'tcp' in line.lower() or 'udp' in line.lower():
                        parts = line.split()
                        if len(parts) >= 4:
                            connections.append({
                                'connection': ' '.join(parts),
                                'raw': line,
                            })
        except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e2:
            print_debug(f"Error using netstat: {e2}")
    
    return connections

def monitor_localhost_8000() -> List[Dict[str, any]]:
    """
    Monitor for connections to localhost:8000 (common exfiltration pattern).
    
    Returns:
        List of suspicious connections to localhost:8000
    """
    suspicious = []
    connections = check_active_connections()
    
    for conn in connections:
        conn_str = str(conn.get('connection', '') or conn.get('raw', '')).lower()
        
        # Check for localhost:8000 or 127.0.0.1:8000
        if 'localhost:8000' in conn_str or '127.0.0.1:8000' in conn_str or ':8000' in conn_str:
            suspicious.append({
                **conn,
                'severity': 'high',
                'reason': 'Connection to localhost:8000 detected - potential exfiltration endpoint',
            })
        
        # Also check for any localhost connections with API paths
        if 'localhost' in conn_str and ('/api/' in conn_str or 'api' in conn_str):
            suspicious.append({
                **conn,
                'severity': 'medium',
                'reason': 'Localhost connection with API endpoint pattern detected',
            })
    
    return suspicious

def detect_url_pattern(url: str) -> Tuple[bool, Optional[str]]:
    """
    Detect suspicious URL patterns matching serial number + timestamp patterns.
    
    Args:
        url: URL to analyze
        
    Returns:
        Tuple of (is_suspicious, reason)
    """
    # Pattern: http://localhost:8000/api/{serial}/{timestamp}
    # Or variations with serial numbers and timestamps
    
    url_lower = url.lower()
    
    # Check for localhost:8000/api pattern
    if 'localhost:8000/api' in url_lower or '127.0.0.1:8000/api' in url_lower:
        # Extract path after /api/
        match = re.search(r'/api/([^/]+)', url_lower)
        if match:
            path_part = match.group(1)
            
            # Check if it looks like a serial number (alphanumeric, typical length)
            if re.match(r'^[a-z0-9]{8,20}$', path_part):
                return True, 'URL pattern matches serial number format in exfiltration endpoint'
            
            # Check for timestamp patterns
            if re.match(r'^\d{10,13}$', path_part):  # Unix timestamp
                return True, 'URL pattern contains timestamp in exfiltration endpoint'
    
    # Check for serial number patterns in any localhost URL
    if 'localhost' in url_lower:
        serial_pattern = r'[A-Z0-9]{10,15}'  # Typical serial number format
        if re.search(serial_pattern, url):
            return True, 'Serial number pattern detected in localhost URL'
    
    return False, None

def analyze_network_activity() -> Dict[str, any]:
    """
    Analyze all network activity for suspicious patterns.
    
    Returns:
        Dictionary with network analysis results
    """
    connections = check_active_connections()
    localhost_8000 = monitor_localhost_8000()
    
    # Analyze all connections for suspicious patterns
    suspicious_urls = []
    for conn in connections:
        conn_str = str(conn.get('connection', '') or conn.get('raw', ''))
        if conn_str:
            is_susp, reason = detect_url_pattern(conn_str)
            if is_susp:
                suspicious_urls.append({
                    **conn,
                    'reason': reason,
                    'severity': 'high',
                })
    
    return {
        'total_connections': len(connections),
        'localhost_8000_connections': localhost_8000,
        'suspicious_urls': suspicious_urls,
        'high_severity_count': len(localhost_8000) + len(suspicious_urls),
        'all_connections': connections,
    }
