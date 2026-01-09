#!/usr/bin/env python3
"""
Quarantine module for isolating detected malware.

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional

import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

import config
from utils.output import print_info, print_warning, print_error, print_success


def add_quarantine_attribute(path: Path) -> bool:
    """
    Add macOS quarantine extended attribute to file.
    
    Args:
        path: File path to quarantine
        
    Returns:
        True if successful
    """
    try:
        # Use xattr to add quarantine attribute
        result = subprocess.run(
            ['xattr', '-w', 'com.apple.quarantine', 
             f'0081;{int(datetime.now().timestamp())};MTDRF;', str(path)],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            print_success(f"Added quarantine attribute to {path}")
            return True
        else:
            print_warning(f"Failed to add quarantine attribute: {result.stderr}")
            return False
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        print_error(f"Error adding quarantine attribute: {e}")
        return False

def quarantine_file(file_path: Path, reason: str = "Detected as suspicious") -> Optional[Path]:
    """
    Quarantine a file by moving it to quarantine directory with extended attributes.
    
    Args:
        file_path: Path to file to quarantine
        reason: Reason for quarantine
        
    Returns:
        Path to quarantined file or None if failed
    """
    if not file_path.exists():
        print_warning(f"File does not exist: {file_path}")
        return None
    
    quarantine_dir = Path(config.QUARANTINE_DIR)
    quarantine_dir.mkdir(parents=True, exist_ok=True)
    
    # Create unique filename with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    quarantined_name = f"{file_path.name}.{timestamp}.quarantined"
    quarantine_path = quarantine_dir / quarantined_name
    
    try:
        # Move file to quarantine
        shutil.move(str(file_path), str(quarantine_path))
        
        # Add quarantine attribute
        add_quarantine_attribute(quarantine_path)
        
        # Create quarantine report
        report_path = create_quarantine_report(quarantine_path, reason)
        
        print_success(f"Quarantined: {file_path} -> {quarantine_path}")
        if report_path:
            print_info(f"Quarantine report: {report_path}")
        
        return quarantine_path
    except OSError as e:
        print_error(f"Failed to quarantine file: {e}")
        return None

def create_quarantine_report(file_path: Path, reason: str) -> Optional[Path]:
    """
    Create a report documenting the quarantine action.
    
    Args:
        file_path: Path to quarantined file
        reason: Reason for quarantine
        
    Returns:
        Path to report file or None if failed
    """
    report_path = file_path.with_suffix(file_path.suffix + '.report.txt')
    
    try:
        with open(report_path, 'w') as f:
            f.write(f"MTDRF Quarantine Report\n")
            f.write(f"{'='*60}\n\n")
            f.write(f"Quarantined File: {file_path}\n")
            f.write(f"Timestamp: {datetime.now().isoformat()}\n")
            f.write(f"Reason: {reason}\n\n")
            
            # Add file metadata
            try:
                stat = file_path.stat()
                f.write(f"File Size: {stat.st_size} bytes\n")
                f.write(f"Modified: {datetime.fromtimestamp(stat.st_mtime).isoformat()}\n")
                f.write(f"Mode: {oct(stat.st_mode)}\n")
            except OSError:
                pass
            
            f.write(f"\nTo restore this file, manually move it from quarantine.\n")
            f.write(f"To permanently delete, use: rm {file_path}\n")
        
        return report_path
    except OSError as e:
        print_warning(f"Failed to create quarantine report: {e}")
        return None

def list_quarantined_files() -> list:
    """
    List all files currently in quarantine.
    
    Returns:
        List of quarantined file paths
    """
    quarantine_dir = Path(config.QUARANTINE_DIR)
    
    if not quarantine_dir.exists():
        return []
    
    quarantined = []
    for file_path in quarantine_dir.glob('*.quarantined'):
        quarantined.append(file_path)
    
    return quarantined

def restore_quarantined_file(quarantined_path: Path, restore_path: Optional[Path] = None) -> bool:
    """
    Restore a file from quarantine.
    
    Args:
        quarantined_path: Path to quarantined file
        restore_path: Optional path to restore to (defaults to original location if detectable)
        
    Returns:
        True if successful
    """
    if not quarantined_path.exists():
        print_error(f"Quarantined file does not exist: {quarantined_path}")
        return False
    
    # Try to determine original path from report
    if restore_path is None:
        report_path = quarantined_path.with_suffix(quarantined_path.suffix + '.report.txt')
        if report_path.exists():
            # Try to extract original path from report (simplified)
            try:
                with open(report_path, 'r') as f:
                    content = f.read()
                    # This is simplified - in real implementation would parse better
                    print_warning("Original path detection not fully implemented")
                    print_info("Please specify restore_path manually")
                    return False
            except OSError:
                pass
        
        print_error("Cannot determine original path - please specify restore_path")
        return False
    
    try:
        # Remove quarantine attribute
        subprocess.run(['xattr', '-d', 'com.apple.quarantine', str(quarantined_path)],
                      timeout=5)
        
        # Move file
        restore_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(quarantined_path), str(restore_path))
        
        print_success(f"Restored: {quarantined_path} -> {restore_path}")
        return True
    except OSError as e:
        print_error(f"Failed to restore file: {e}")
        return False
