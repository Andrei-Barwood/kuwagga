#!/usr/bin/env python3
"""
Binary forensics module for deep analysis of suspected binaries.

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils.output import print_debug, print_info, print_warning
from detectors import binary_analyzer


def analyze_code_signature(binary_path: Path) -> Dict[str, any]:
    """
    Perform full code signature analysis.
    
    Args:
        binary_path: Path to binary
        
    Returns:
        Dictionary with comprehensive signature analysis
    """
    signature_info = binary_analyzer.check_code_signature(binary_path)
    
    if not signature_info:
        return {
            'status': 'error',
            'message': 'Could not analyze signature',
        }
    
    analysis = {
        'signature_info': signature_info,
        'is_suspicious': binary_analyzer.is_suspicious_signature(signature_info),
        'signature_type': signature_info.get('signature', 'unknown'),
        'team_identifier': signature_info.get('teamidentifier', 'not set'),
        'format': signature_info.get('format', 'unknown'),
    }
    
    # Detailed signature flags
    flags = signature_info.get('flags', '')
    analysis['flags'] = flags
    analysis['is_ad_hoc'] = 'adhoc' in flags.lower()
    analysis['is_linker_signed'] = 'linker-signed' in flags.lower()
    analysis['has_team_id'] = analysis['team_identifier'].lower() not in ['not set', '-', '']
    
    return analysis

def check_entitlements(binary_path: Path) -> Dict[str, any]:
    """
    Extract entitlements from binary.
    
    Args:
        binary_path: Path to binary
        
    Returns:
        Dictionary with entitlements information
    """
    entitlements = {
        'available': False,
        'entitlements': {},
    }
    
    try:
        result = subprocess.run(
            ['codesign', '-d', '--entitlements', ':-', str(binary_path)],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            entitlements['available'] = True
            # Parse entitlements (simplified - full parsing would use plistlib)
            entitlements_text = result.stdout
            entitlements['raw'] = entitlements_text
            
            # Look for common suspicious entitlements
            suspicious_entitlements = []
            if 'com.apple.security.cs.allow-unsigned-executable-memory' in entitlements_text:
                suspicious_entitlements.append('allow-unsigned-executable-memory')
            if 'com.apple.security.cs.disable-library-validation' in entitlements_text:
                suspicious_entitlements.append('disable-library-validation')
            if 'com.apple.security.cs.allow-jit' in entitlements_text:
                suspicious_entitlements.append('allow-jit')
            
            entitlements['suspicious'] = suspicious_entitlements
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        print_debug(f"Error checking entitlements: {e}")
        entitlements['error'] = str(e)
    
    return entitlements

def generate_forensic_report(binary_path: Path) -> Dict[str, any]:
    """
    Generate comprehensive forensic report for a binary.
    
    Args:
        binary_path: Path to binary to analyze
        
    Returns:
        Comprehensive forensic report dictionary
    """
    if not binary_path.exists():
        return {
            'error': 'File does not exist',
            'path': str(binary_path),
        }
    
    print_info(f"Generating forensic report for: {binary_path}")
    
    # Extract strings
    strings_set = binary_analyzer.extract_strings(binary_path)
    
    # Analyze signature
    signature_analysis = analyze_code_signature(binary_path)
    
    # Check entitlements
    entitlements = check_entitlements(binary_path)
    
    # Get file metadata
    try:
        stat = binary_path.stat()
        file_metadata = {
            'size': stat.st_size,
            'modified': stat.st_mtime,
            'accessed': stat.st_atime,
            'created': stat.st_ctime,
            'mode': oct(stat.st_mode),
            'owner': stat.st_uid,
            'group': stat.st_gid,
        }
    except OSError as e:
        file_metadata = {'error': str(e)}
    
    # Analyze strings for indicators
    indicators = binary_analyzer.check_stealer_indicators(strings_set)
    
    # Count indicators
    total_indicators = sum(len(v) for v in indicators.values())
    
    # Determine severity
    severity = 'low'
    if total_indicators >= 5 or signature_analysis.get('is_suspicious'):
        severity = 'high'
    elif total_indicators >= 2:
        severity = 'medium'
    
    report = {
        'file_path': str(binary_path),
        'file_metadata': file_metadata,
        'signature_analysis': signature_analysis,
        'entitlements': entitlements,
        'strings_analysis': {
            'total_strings': len(strings_set),
            'indicators': indicators,
            'indicator_count': total_indicators,
        },
        'severity': severity,
        'recommendations': [],
    }
    
    # Add recommendations
    if signature_analysis.get('is_suspicious'):
        report['recommendations'].append('Binary has suspicious signature - consider quarantine')
    
    if total_indicators >= 3:
        report['recommendations'].append('Multiple stealer malware indicators detected')
    
    if entitlements.get('suspicious'):
        report['recommendations'].append('Binary has suspicious entitlements')
    
    if not report['recommendations']:
        report['recommendations'].append('No immediate threats detected, but review recommended')
    
    return report
