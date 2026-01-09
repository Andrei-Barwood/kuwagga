#!/usr/bin/env python3
"""
Configuration management for macOS Threat Detection & Response Framework (MTDRF)

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import os
from pathlib import Path
from typing import Dict, List, Optional

# Sensitive file paths to monitor
SENSITIVE_PATHS = {
    'chrome': [
        Path.home() / 'Library/Application Support/Google/Chrome/Default/Cookies',
        Path.home() / 'Library/Application Support/Google/Chrome/Default/Login Data',
    ],
    'exodus': [
        Path.home() / 'Library/Application Support/Exodus/exodus.wallet/passphrase.json',
        Path.home() / 'Library/Application Support/Exodus/exodus.wallet/seed.seco',
        Path.home() / 'Library/Application Support/Exodus/exodus.wallet/storage.seco',
    ],
    'electrum': [
        Path.home() / 'Library/Application Support/Electrum/wallets',
    ],
    'other_wallets': [
        Path.home() / 'Library/Application Support/Bitcoin',
        Path.home() / 'Library/Application Support/Ethereum',
        Path.home() / 'Library/Application Support/MetaMask',
    ],
}

# Suspicious indicators to detect
STEALER_INDICATORS = [
    '/usr/sbin/system_profiler',
    'SPHardwareDataType',
    'Serial Number (system):',
    'Chrome Safe Storage',
    'http://localhost:8000/api/',
    'localhost:8000',
    'SecItemCopyMatching',
    'kSecClassGenericPassword',
]

# Detection thresholds
DETECTION_THRESHOLDS = {
    'suspicious_strings': 2,  # Number of suspicious strings to flag binary
    'process_monitor_interval': 5,  # Seconds between process checks
    'file_monitor_interval': 1,  # Seconds between file checks
    'network_check_interval': 2,  # Seconds between network checks
}

# Output configuration
OUTPUT_CONFIG = {
    'format': 'cli',  # 'cli', 'json', 'both'
    'use_colors': True,
    'verbose': False,
    'output_file': None,
}

# Logging configuration
LOGGING_CONFIG = {
    'level': 'INFO',  # DEBUG, INFO, WARNING, ERROR
    'file': None,  # Path to log file, None for stdout
    'audit_trail': True,
}

# Quarantine directory
QUARANTINE_DIR = Path.home() / '.mtdrf_quarantine'
QUARANTINE_DIR.mkdir(exist_ok=True)

# Whitelist/Blacklist
WHITELIST_PATHS: List[str] = []
BLACKLIST_PATHS: List[str] = []

# Permission detection
REQUIRE_ADMIN_FOR = [
    'firewall_rules',
    'tcc_protection',
    'system_log_access',
]

# Terminal color compatibility
TERMINAL_COLORS = {
    'true_color': True,  # Try true-color first
    '256_color': True,   # Fallback to 256-color
    'fallback': True,    # Fallback to basic colors
}

def get_config() -> Dict:
    """Get complete configuration dictionary."""
    return {
        'sensitive_paths': SENSITIVE_PATHS,
        'stealer_indicators': STEALER_INDICATORS,
        'detection_thresholds': DETECTION_THRESHOLDS,
        'output': OUTPUT_CONFIG,
        'logging': LOGGING_CONFIG,
        'quarantine_dir': str(QUARANTINE_DIR),
        'whitelist': WHITELIST_PATHS,
        'blacklist': BLACKLIST_PATHS,
        'require_admin': REQUIRE_ADMIN_FOR,
        'terminal_colors': TERMINAL_COLORS,
    }

def update_config(key: str, value) -> None:
    """Update configuration value."""
    if key == 'verbose':
        OUTPUT_CONFIG['verbose'] = value
    elif key == 'output_format':
        OUTPUT_CONFIG['format'] = value
    elif key == 'no_color':
        OUTPUT_CONFIG['use_colors'] = not value
    elif key == 'output_file':
        OUTPUT_CONFIG['output_file'] = value
    elif key == 'log_level':
        LOGGING_CONFIG['level'] = value
