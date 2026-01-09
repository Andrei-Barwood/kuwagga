#!/usr/bin/env python3
"""
Process analyzer for analyzing running processes and process trees.

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import psutil
import subprocess
from typing import Dict, List, Optional

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils.output import print_debug, print_warning
from detectors import process_monitor


def get_process_tree(pid: int, depth: int = 3) -> Optional[Dict[str, any]]:
    """
    Build detailed process tree for a given PID.
    
    Args:
        pid: Process ID
        depth: Maximum depth to traverse
        
    Returns:
        Dictionary with process tree information
    """
    return process_monitor.check_process_tree(pid)

def analyze_process_memory(pid: int) -> Dict[str, any]:
    """
    Analyze process memory usage and characteristics.
    Note: This is limited without special permissions.
    
    Args:
        pid: Process ID
        
    Returns:
        Dictionary with memory analysis
    """
    memory_info = {
        'available': False,
        'error': None,
    }
    
    try:
        proc = psutil.Process(pid)
        mem_info = proc.memory_info()
        mem_percent = proc.memory_percent()
        
        memory_info['available'] = True
        memory_info['rss'] = mem_info.rss  # Resident Set Size
        memory_info['vms'] = mem_info.vms  # Virtual Memory Size
        memory_info['percent'] = mem_percent
        
        # Get memory maps (may require permissions)
        try:
            memory_maps = proc.memory_maps()
            memory_info['memory_maps_count'] = len(memory_maps)
            memory_info['memory_maps'] = [str(mmap.path) for mmap in memory_maps[:10]]  # First 10
        except (psutil.AccessDenied, psutil.NoSuchProcess):
            memory_info['memory_maps'] = 'Access denied or process not found'
        
    except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
        memory_info['error'] = str(e)
        print_debug(f"Error analyzing process memory for PID {pid}: {e}")
    
    return memory_info

def check_process_network(pid: int) -> Dict[str, any]:
    """
    Check network connections for a specific process.
    
    Args:
        pid: Process ID
        
    Returns:
        Dictionary with network connection information
    """
    network_info = {
        'connections': [],
        'error': None,
    }
    
    try:
        proc = psutil.Process(pid)
        connections = proc.connections()
        
        for conn in connections:
            conn_info = {
                'family': str(conn.family),
                'type': str(conn.type),
                'status': conn.status if conn.status else 'N/A',
            }
            
            if conn.laddr:
                conn_info['local_address'] = f"{conn.laddr.ip}:{conn.laddr.port}"
            
            if conn.raddr:
                conn_info['remote_address'] = f"{conn.raddr.ip}:{conn.raddr.port}"
            
            network_info['connections'].append(conn_info)
        
    except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
        network_info['error'] = str(e)
        print_debug(f"Error checking process network for PID {pid}: {e}")
    
    return network_info

def analyze_process(pid: int) -> Dict[str, any]:
    """
    Perform comprehensive analysis of a process.
    
    Args:
        pid: Process ID
        
    Returns:
        Comprehensive process analysis dictionary
    """
    try:
        proc = psutil.Process(pid)
        
        analysis = {
            'pid': pid,
            'name': proc.name(),
            'cmdline': proc.cmdline(),
            'exe': proc.exe() if proc.exe() else 'N/A',
            'cwd': proc.cwd() if proc.cwd() else 'N/A',
            'ppid': proc.ppid(),
            'username': proc.username(),
            'status': proc.status(),
            'create_time': proc.create_time(),
            'cpu_percent': proc.cpu_percent(interval=0.1),
            'num_threads': proc.num_threads(),
            'process_tree': get_process_tree(pid),
            'memory': analyze_process_memory(pid),
            'network': check_process_network(pid),
        }
        
        # Check for suspicious characteristics
        suspicious_flags = []
        
        if analysis['process_tree'] and analysis['process_tree'].get('parent'):
            parent_name = analysis['process_tree']['parent'].get('name', '').lower()
            if parent_name not in ['loginwindow', 'kernel_task', 'launchd']:
                suspicious_flags.append('Unusual parent process')
        
        if analysis['network']['connections']:
            for conn in analysis['network']['connections']:
                remote = conn.get('remote_address', '')
                if 'localhost:8000' in remote or '127.0.0.1:8000' in remote:
                    suspicious_flags.append('Connection to localhost:8000 (suspicious)')
        
        analysis['suspicious_flags'] = suspicious_flags
        analysis['severity'] = 'high' if suspicious_flags else 'low'
        
        return analysis
        
    except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
        return {
            'pid': pid,
            'error': str(e),
            'available': False,
        }
