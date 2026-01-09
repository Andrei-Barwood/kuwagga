#!/usr/bin/env python3
"""
Binary analyzer for detecting ad-hoc signed binaries and suspicious signing patterns.

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set

import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

import config
from utils.output import print_debug, print_info, print_warning


def is_mach_o_binary(file_path: Path) -> bool:
    """
    Check if file is a Mach-O binary.
    
    Args:
        file_path: Path to file to check
        
    Returns:
        True if file is Mach-O binary
    """
    try:
        result = subprocess.run(
            ['file', str(file_path)],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            output = result.stdout.lower()
            return 'mach-o' in output
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    
    return False

def check_code_signature(binary_path: Path) -> Optional[Dict[str, str]]:
    """
    Check code signature of a binary using codesign.
    
    Args:
        binary_path: Path to binary to check
        
    Returns:
        Dictionary with signature information or None if error
    """
    try:
        result = subprocess.run(
            ['codesign', '-dvv', str(binary_path)],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        signature_info = {}
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if ':' in line:
                    key, value = line.split(':', 1)
                    key = key.strip()
                    value = value.strip()
                    signature_info[key.lower()] = value
            return signature_info
        else:
            # Check if binary is unsigned
            if 'code object is not signed' in result.stderr.lower():
                signature_info['status'] = 'unsigned'
                return signature_info
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        print_debug(f"Error checking signature for {binary_path}: {e}")
    
    return None

def is_suspicious_signature(signature_info: Dict[str, str]) -> bool:
    """
    Determine if signature is suspicious (ad-hoc, linker-signed, no TeamIdentifier).
    
    Args:
        signature_info: Signature information dictionary
        
    Returns:
        True if signature is suspicious
    """
    if not signature_info:
        return True  # Unsigned binaries are suspicious
    
    # Check for ad-hoc signature
    signature = signature_info.get('signature', '').lower()
    if 'adhoc' in signature:
        return True
    
    # Check for linker-signed without TeamIdentifier
    flags = signature_info.get('flags', '').lower()
    if 'linker-signed' in flags:
        team_id = signature_info.get('teamidentifier', 'not set')
        if 'not set' in team_id.lower() or not team_id or team_id == '-':
            return True
    
    # Check if unsigned
    if signature_info.get('status') == 'unsigned':
        return True
    
    return False

def extract_strings(binary_path: Path) -> Set[str]:
    """
    Extract strings from binary using macOS strings utility.
    
    Args:
        binary_path: Path to binary
        
    Returns:
        Set of extracted strings
    """
    strings_set = set()
    
    try:
        result = subprocess.run(
            ['strings', str(binary_path)],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            strings_set = set(result.stdout.splitlines())
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        print_debug(f"Error extracting strings from {binary_path}: {e}")
    
    return strings_set

def check_stealer_indicators(strings: Set[str]) -> Dict[str, List[str]]:
    """
    Check for stealer malware indicators in extracted strings.
    
    Args:
        strings: Set of extracted strings
        
    Returns:
        Dictionary mapping indicator categories to found strings
    """
    indicators = {
        'system_profiler': [],
        'chrome': [],
        'exodus': [],
        'network_exfiltration': [],
        'keychain': [],
    }
    
    for string in strings:
        string_lower = string.lower()
        
        # System profiler indicators
        if 'system_profiler' in string_lower or 'sphardwaredatatype' in string_lower:
            indicators['system_profiler'].append(string)
        if 'serial number' in string_lower:
            indicators['system_profiler'].append(string)
        
        # Chrome indicators
        if 'chrome safe storage' in string_lower:
            indicators['chrome'].append(string)
        if 'chrome' in string_lower and ('cookie' in string_lower or 'login' in string_lower):
            indicators['chrome'].append(string)
        
        # Exodus wallet indicators
        if 'exodus' in string_lower:
            indicators['exodus'].append(string)
        if 'passphrase.json' in string_lower or 'seed.seco' in string_lower:
            indicators['exodus'].append(string)
        
        # Network exfiltration indicators
        if 'localhost:8000' in string_lower or 'localhost:8000/api' in string_lower:
            indicators['network_exfiltration'].append(string)
        
        # Keychain indicators
        if 'secitemcopymatching' in string_lower or 'ksecclassgenericpassword' in string_lower:
            indicators['keychain'].append(string)
    
    return indicators

def scan_directory(directory: Path, recursive: bool = True) -> List[Dict[str, any]]:
    """
    Scan directory for Mach-O binaries and analyze them.
    
    Args:
        directory: Directory to scan
        recursive: Whether to scan recursively
        
    Returns:
        List of detection results
    """
    results = []
    
    if not directory.exists() or not directory.is_dir():
        print_warning(f"Directory does not exist or is not a directory: {directory}")
        return results
    
    print_info(f"Scanning directory: {directory}")
    
    pattern = "**/*" if recursive else "*"
    
    for file_path in directory.glob(pattern):
        if not file_path.is_file():
            continue
        
        # Skip common non-binary files
        if file_path.suffix in ['.txt', '.md', '.py', '.sh', '.zsh', '.json', '.xml', '.html']:
            continue
        
        # Check if it's a Mach-O binary
        if not is_mach_o_binary(file_path):
            continue
        
        print_debug(f"Analyzing binary: {file_path}")
        
        # Check signature
        signature_info = check_code_signature(file_path)
        is_suspicious = is_suspicious_signature(signature_info) if signature_info else True
        
        if is_suspicious:
            # Extract strings and check for indicators
            strings = extract_strings(file_path)
            indicators = check_stealer_indicators(strings)
            
            # Count total indicator matches
            total_indicators = sum(len(v) for v in indicators.values())
            
            # Check threshold
            threshold = config.DETECTION_THRESHOLDS.get('suspicious_strings', 2)
            
            if total_indicators >= threshold or is_suspicious:
                result = {
                    'file_path': str(file_path),
                    'suspicious_signature': is_suspicious,
                    'signature_info': signature_info,
                    'indicators': indicators,
                    'indicator_count': total_indicators,
                    'severity': 'high' if total_indicators >= threshold else 'medium',
                }
                results.append(result)
    
    return results
