#!/usr/bin/env python3
"""
Process monitor for detecting suspicious process behavior and system_profiler calls.

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import psutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional

sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.output import print_debug, print_info, print_warning


def get_running_processes() -> List[Dict[str, any]]:
    """
    Get list of currently running processes.
    
    Returns:
        List of process information dictionaries
    """
    processes = []
    
    try:
        for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'ppid', 'username', 'exe']):
            try:
                proc_info = proc.info
                processes.append(proc_info)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
    except Exception as e:
        print_warning(f"Error getting processes: {e}")
    
    return processes

def check_process_tree(pid: int) -> Optional[Dict[str, any]]:
    """
    Analyze process tree for a given PID.
    
    Args:
        pid: Process ID
        
    Returns:
        Dictionary with process tree information
    """
    try:
        proc = psutil.Process(pid)
        
        tree_info = {
            'pid': pid,
            'name': proc.name(),
            'cmdline': proc.cmdline(),
            'ppid': proc.ppid(),
            'children': [],
            'parent': None,
        }
        
        # Get parent process
        try:
            parent = proc.parent()
            if parent:
                tree_info['parent'] = {
                    'pid': parent.pid,
                    'name': parent.name(),
                    'cmdline': parent.cmdline(),
                }
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
        
        # Get child processes
        try:
            children = proc.children(recursive=False)
            for child in children:
                tree_info['children'].append({
                    'pid': child.pid,
                    'name': child.name(),
                    'cmdline': child.cmdline(),
                })
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
        
        return tree_info
    except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
        print_debug(f"Error analyzing process tree for PID {pid}: {e}")
        return None

def monitor_system_profiler() -> List[Dict[str, any]]:
    """
    Monitor for system_profiler executions, especially with SPHardwareDataType.
    
    Returns:
        List of suspicious system_profiler processes
    """
    suspicious = []
    
    processes = get_running_processes()
    
    for proc_info in processes:
        name = proc_info.get('name', '').lower()
        cmdline = proc_info.get('cmdline', [])
        
        # Check for system_profiler
        if 'system_profiler' in name or any('system_profiler' in str(arg).lower() for arg in cmdline):
            # Check for SPHardwareDataType argument
            cmdline_str = ' '.join(str(arg) for arg in cmdline).lower()
            if 'sphardwaredatatype' in cmdline_str:
                result = {
                    'pid': proc_info.get('pid'),
                    'name': proc_info.get('name'),
                    'cmdline': cmdline,
                    'ppid': proc_info.get('ppid'),
                    'username': proc_info.get('username'),
                    'severity': 'high',
                    'reason': 'system_profiler called with SPHardwareDataType (suspicious - may be extracting serial number)',
                }
                suspicious.append(result)
    
    return suspicious

def detect_suspicious_patterns() -> List[Dict[str, any]]:
    """
    Detect processes exhibiting stealer malware behavior patterns.
    
    Returns:
        List of suspicious processes
    """
    suspicious = []
    
    processes = get_running_processes()
    
    for proc_info in processes:
        cmdline = proc_info.get('cmdline', [])
        cmdline_str = ' '.join(str(arg) for arg in cmdline).lower()
        name = proc_info.get('name', '').lower()
        
        patterns = []
        
        # Check for Chrome-related access patterns
        if any('chrome' in str(arg).lower() and ('cookie' in str(arg).lower() or 'login' in str(arg).lower()) for arg in cmdline):
            patterns.append('Accessing Chrome credential files')
        
        # Check for Exodus wallet access
        if any('exodus' in str(arg).lower() for arg in cmdline):
            patterns.append('Accessing Exodus wallet files')
        
        # Check for Keychain access (would require more advanced monitoring)
        # This is a simplified check
        
        # Check for localhost:8000 connections (will be caught by network monitor)
        
        if patterns:
            result = {
                'pid': proc_info.get('pid'),
                'name': proc_info.get('name'),
                'cmdline': cmdline,
                'ppid': proc_info.get('ppid'),
                'username': proc_info.get('username'),
                'severity': 'medium',
                'patterns': patterns,
                'reason': 'Process exhibits suspicious file access patterns',
            }
            suspicious.append(result)
    
    # Also check for system_profiler calls
    system_profiler_suspicious = monitor_system_profiler()
    suspicious.extend(system_profiler_suspicious)
    
    return suspicious
