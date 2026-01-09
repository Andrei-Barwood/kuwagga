#!/usr/bin/env python3
"""
Cleanup module for removing malware and system artifacts after infection.

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import os
import shutil
from pathlib import Path
from typing import Dict, List

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import config
from utils.output import print_info, print_warning, print_error, print_success
from mitigators import quarantine


def remove_malware_files(detected_paths: List[Path], quarantine_first: bool = True) -> Dict[str, any]:
    """
    Safely remove infected files, optionally quarantining first.
    
    Args:
        detected_paths: List of file paths to remove
        quarantine_first: Whether to quarantine before removal (recommended)
        
    Returns:
        Dictionary with cleanup results
    """
    results = {
        'quarantined': [],
        'removed': [],
        'failed': [],
    }
    
    for file_path in detected_paths:
        path = Path(file_path)
        
        if not path.exists():
            results['failed'].append({
                'path': str(path),
                'reason': 'File does not exist',
            })
            continue
        
        # Quarantine first if requested
        if quarantine_first:
            quarantined = quarantine.quarantine_file(path, reason="Malware detection - cleaning up")
            if quarantined:
                results['quarantined'].append(str(quarantined))
                # Remove from quarantine after user review (optional)
                # For now, we quarantine only
                continue
        
        # Remove file
        try:
            if path.is_file():
                path.unlink()
            elif path.is_dir():
                shutil.rmtree(path)
            
            results['removed'].append(str(path))
            print_success(f"Removed: {path}")
        except OSError as e:
            results['failed'].append({
                'path': str(path),
                'reason': str(e),
            })
            print_error(f"Failed to remove {path}: {e}")
    
    return results

def clean_system_artifacts() -> Dict[str, any]:
    """
    Clean system artifacts left by malware (registry entries, log entries, etc.).
    Note: On macOS, this is more limited than on Windows.
    
    Returns:
        Dictionary with cleanup results
    """
    results = {
        'cleaned': [],
        'notes': [],
    }
    
    # macOS doesn't have a registry, but we can clean:
    # 1. Launch Agents/Daemons
    # 2. Login items
    # 3. Browser extensions
    # 4. Suspicious processes
    
    print_info("System artifact cleanup on macOS:")
    print_info("1. Check ~/Library/LaunchAgents for suspicious launch agents")
    print_info("2. Check ~/Library/LaunchDaemons (requires admin)")
    print_info("3. Check System Preferences > Users & Groups > Login Items")
    print_info("4. Check browser extensions manually")
    
    results['notes'].extend([
        "Manual review of Launch Agents recommended",
        "Check Login Items in System Preferences",
        "Review browser extensions",
    ])
    
    # Check for common malware locations
    suspicious_locations = [
        Path.home() / 'Library/LaunchAgents',
        Path.home() / 'Library/Application Support',
    ]
    
    for location in suspicious_locations:
        if location.exists():
            results['notes'].append(f"Review files in: {location}")
    
    return results

def verify_cleanup(detected_paths: List[Path]) -> Dict[str, any]:
    """
    Verify that cleanup was successful.
    
    Args:
        detected_paths: List of paths that were cleaned
        
    Returns:
        Dictionary with verification results
    """
    results = {
        'verified_removed': [],
        'still_exists': [],
        'quarantined': [],
    }
    
    quarantine_dir = Path(config.QUARANTINE_DIR)
    
    for file_path in detected_paths:
        path = Path(file_path)
        
        if not path.exists():
            results['verified_removed'].append(str(path))
        else:
            results['still_exists'].append(str(path))
            print_warning(f"File still exists: {path}")
        
        # Check if quarantined
        if quarantine_dir.exists():
            for quarantined in quarantine_dir.glob(f"*{path.name}*"):
                results['quarantined'].append(str(quarantined))
    
    return results
