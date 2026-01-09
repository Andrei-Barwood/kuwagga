#!/usr/bin/env python3
"""
File protection module for hardening file access to sensitive locations.

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import os
import shutil
from pathlib import Path
from typing import Dict, List, Optional

import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

import config
from utils.output import print_info, print_warning, print_error, print_success
from utils.permissions import check_admin_privileges


def set_file_permissions(path: Path, mode: int = 0o600) -> bool:
    """
    Set restrictive file permissions.
    
    Args:
        path: File path
        mode: Permission mode (default: 0o600 = rw-------)
        
    Returns:
        True if successful
    """
    try:
        os.chmod(path, mode)
        print_success(f"Set permissions on {path} to {oct(mode)}")
        return True
    except OSError as e:
        print_error(f"Failed to set permissions on {path}: {e}")
        return False

def create_protected_backup(path: Path, backup_dir: Optional[Path] = None) -> Optional[Path]:
    """
    Create secure backup of file before applying protection.
    
    Args:
        path: File to backup
        backup_dir: Directory for backup (defaults to ~/.mtdrf_backups)
        
    Returns:
        Path to backup file or None if failed
    """
    if not path.exists():
        print_warning(f"File does not exist: {path}")
        return None
    
    if backup_dir is None:
        backup_dir = Path.home() / '.mtdrf_backups'
    
    backup_dir.mkdir(parents=True, exist_ok=True)
    backup_path = backup_dir / f"{path.name}.{int(path.stat().st_mtime)}.backup"
    
    try:
        shutil.copy2(path, backup_path)
        print_success(f"Created backup: {backup_path}")
        return backup_path
    except OSError as e:
        print_error(f"Failed to create backup: {e}")
        return None

def apply_tcc_protection() -> bool:
    """
    Apply TCC (Transparency, Consent, and Control) protection.
    Note: This requires admin privileges and system-level configuration.
    
    Returns:
        True if successful (or if admin not available, returns False)
    """
    if not check_admin_privileges():
        print_warning("TCC protection requires administrator privileges")
        return False
    
    # TCC protection would typically involve:
    # 1. Modifying system preferences
    # 2. Using tccutil command-line tool
    # 3. System-level configuration
    
    print_info("TCC protection requires system-level configuration")
    print_info("Use 'tccutil' command or System Preferences > Security & Privacy")
    return False

def protect_sensitive_files() -> Dict[str, any]:
    """
    Apply protection to all sensitive files defined in config.
    
    Returns:
        Dictionary with protection results
    """
    results = {
        'protected': [],
        'failed': [],
        'backups_created': [],
    }
    
    for category, paths in config.SENSITIVE_PATHS.items():
        for file_path in paths:
            path = Path(file_path)
            
            if not path.exists():
                continue
            
            # Create backup first
            backup = create_protected_backup(path)
            if backup:
                results['backups_created'].append(str(backup))
            
            # Set restrictive permissions
            if set_file_permissions(path, 0o600):
                results['protected'].append({
                    'path': str(path),
                    'category': category,
                    'permissions': '0o600',
                })
            else:
                results['failed'].append({
                    'path': str(path),
                    'category': category,
                    'reason': 'Failed to set permissions',
                })
    
    return results

def monitor_and_alert() -> None:
    """
    Monitor file access and alert on unauthorized access attempts.
    Note: This is a placeholder - real implementation requires FSEvents or similar.
    """
    print_info("File monitoring requires FSEvents integration")
    print_info("Use file_monitor module for basic file monitoring")
