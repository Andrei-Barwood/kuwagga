#!/usr/bin/env python3
"""
Recovery module for restoring data and generating password change checklists.

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import shutil
from pathlib import Path
from typing import Dict, List

import sys
sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.output import print_info, print_warning, print_success


def restore_chrome_data(backup_path: Path, restore_location: Path = None) -> bool:
    """
    Restore Chrome data from backup.
    
    Args:
        backup_path: Path to backup directory or file
        restore_location: Where to restore (defaults to Chrome default location)
        
    Returns:
        True if successful
    """
    backup = Path(backup_path)
    
    if not backup.exists():
        print_warning(f"Backup does not exist: {backup}")
        return False
    
    if restore_location is None:
        restore_location = Path.home() / 'Library/Application Support/Google/Chrome/Default'
    
    restore_location.parent.mkdir(parents=True, exist_ok=True)
    
    try:
        if backup.is_file():
            # Restore single file
            shutil.copy2(backup, restore_location)
            print_success(f"Restored Chrome file: {backup} -> {restore_location}")
        elif backup.is_dir():
            # Restore directory
            if restore_location.exists():
                print_warning(f"Restore location exists: {restore_location}")
                print_info("Backing up existing location first...")
                existing_backup = restore_location.with_suffix('.existing_backup')
                shutil.move(str(restore_location), str(existing_backup))
            
            shutil.copytree(backup, restore_location)
            print_success(f"Restored Chrome data: {backup} -> {restore_location}")
        
        return True
    except OSError as e:
        print_warning(f"Failed to restore Chrome data: {e}")
        return False

def restore_exodus_wallet(backup_path: Path, restore_location: Path = None) -> bool:
    """
    Restore Exodus wallet from backup.
    
    Args:
        backup_path: Path to backup file
        restore_location: Where to restore (defaults to Exodus wallet location)
        
    Returns:
        True if successful
    """
    backup = Path(backup_path)
    
    if not backup.exists():
        print_warning(f"Backup does not exist: {backup}")
        return False
    
    if restore_location is None:
        restore_location = Path.home() / 'Library/Application Support/Exodus/exodus.wallet'
        restore_location.parent.mkdir(parents=True, exist_ok=True)
    
    try:
        if backup.is_file():
            # Determine target file name
            if backup.name.endswith('.backup'):
                target_name = backup.name.replace('.backup', '')
            else:
                target_name = backup.name
            
            target = restore_location / target_name if restore_location.is_dir() else restore_location
            
            if target.exists():
                # Backup existing
                existing_backup = target.with_suffix(target.suffix + '.old')
                shutil.move(str(target), str(existing_backup))
            
            shutil.copy2(backup, target)
            print_success(f"Restored Exodus wallet: {backup} -> {target}")
            return True
        else:
            print_warning("Backup must be a file for Exodus wallet restore")
            return False
    except OSError as e:
        print_warning(f"Failed to restore Exodus wallet: {e}")
        return False

def change_all_passwords() -> Dict[str, List[str]]:
    """
    Generate password change checklist for compromised accounts.
    
    Returns:
        Dictionary with password change recommendations
    """
    checklist = {
        'critical': [
            'All banking and financial accounts',
            'Email accounts (primary and secondary)',
            'Password manager master password',
            'Apple ID / iCloud account',
            'Crypto exchange accounts',
            'Crypto wallet passphrases (if compromised)',
        ],
        'high_priority': [
            'Social media accounts',
            'Cloud storage (Google Drive, Dropbox, iCloud)',
            'Shopping accounts (Amazon, etc.)',
            'Work/school accounts',
            'GitHub, GitLab, and development accounts',
        ],
        'medium_priority': [
            'Streaming services',
            'Online gaming accounts',
            'Forums and community accounts',
        ],
        'additional_steps': [
            'Enable two-factor authentication (2FA) on all accounts',
            'Review account activity logs for suspicious access',
            'Check for unauthorized transactions',
            'Review browser extensions and remove suspicious ones',
            'Scan system with antivirus software',
            'Review and update system security settings',
            'Check credit reports for suspicious activity',
        ],
    }
    
    print_info("Password Change Checklist:")
    print_info("=" * 60)
    
    for priority, items in checklist.items():
        if items:
            print_info(f"\n{priority.upper().replace('_', ' ')}:")
            for item in items:
                print_info(f"  - {item}")
    
    return checklist

def generate_recovery_report(incident_details: Dict) -> str:
    """
    Generate a comprehensive recovery report.
    
    Args:
        incident_details: Dictionary with incident information
        
    Returns:
        Formatted recovery report string
    """
    report_lines = [
        "MTDRF Recovery Report",
        "=" * 60,
        "",
        "Incident Summary:",
        f"  Date: {incident_details.get('date', 'Unknown')}",
        f"  Detected Threats: {len(incident_details.get('threats', []))}",
        "",
        "Actions Taken:",
    ]
    
    for action in incident_details.get('actions', []):
        report_lines.append(f"  - {action}")
    
    report_lines.extend([
        "",
        "Recovery Steps:",
        "  1. Change all passwords (see checklist)",
        "  2. Enable 2FA on all accounts",
        "  3. Review account activity",
        "  4. Restore data from clean backups if needed",
        "  5. Monitor for additional suspicious activity",
        "",
        "Password Change Checklist:",
    ])
    
    checklist = change_all_passwords()
    for priority, items in checklist.items():
        if items:
            report_lines.append(f"\n  {priority.upper().replace('_', ' ')}:")
            for item in items:
                report_lines.append(f"    - {item}")
    
    return "\n".join(report_lines)
