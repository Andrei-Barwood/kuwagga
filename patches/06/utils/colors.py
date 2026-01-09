#!/usr/bin/env python3
"""
Color palette constants and mappings for macOS Threat Detection & Response Framework (MTDRF)

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

from typing import Dict, Tuple, Optional

# Color palette hex codes
COLOR_PALETTE: Dict[str, str] = {
    'light_yellow': '#FFFFB8',
    'yellow': '#FFFF99',
    'light_purple_lavender': '#DEDDFA',
    'purple': '#A6A4D7',
    'dark_gray_purple': '#63627C',
    'dark_blue': '#485199',
    'blue': '#5A64BF',
    'light_blue_gray': '#D7E0EC',
    'light_purple': '#C2C0E3',
    'blue_gray': '#A7B7CF',
    'light_blue_gray_border': '#BCC5D9',
}

# Severity level to color mapping
SEVERITY_COLORS: Dict[str, str] = {
    'critical': COLOR_PALETTE['dark_blue'],
    'high': COLOR_PALETTE['dark_blue'],
    'medium': COLOR_PALETTE['yellow'],
    'low': COLOR_PALETTE['light_yellow'],
    'info': COLOR_PALETTE['light_yellow'],
    'success': COLOR_PALETTE['light_purple'],
    'warning': COLOR_PALETTE['yellow'],
    'error': COLOR_PALETTE['dark_blue'],
    'debug': COLOR_PALETTE['blue_gray'],
}

# Message type to color mapping
MESSAGE_TYPE_COLORS: Dict[str, str] = {
    'header': COLOR_PALETTE['purple'],
    'section_header': COLOR_PALETTE['purple'],
    'title': COLOR_PALETTE['purple'],
    'success': COLOR_PALETTE['light_purple'],
    'warning': COLOR_PALETTE['yellow'],
    'error': COLOR_PALETTE['dark_blue'],
    'info': COLOR_PALETTE['light_yellow'],
    'debug': COLOR_PALETTE['blue_gray'],
    'metadata': COLOR_PALETTE['dark_gray_purple'],
    'timestamp': COLOR_PALETTE['dark_gray_purple'],
    'path': COLOR_PALETTE['dark_gray_purple'],
    'pid': COLOR_PALETTE['dark_gray_purple'],
    'primary_action': COLOR_PALETTE['blue'],
    'border': COLOR_PALETTE['light_blue_gray_border'],
    'background': COLOR_PALETTE['light_blue_gray'],
    'secondary_info': COLOR_PALETTE['light_purple_lavender'],
}

def get_color(name: str) -> Optional[str]:
    """
    Get hex code for named color.
    
    Args:
        name: Color name from COLOR_PALETTE
        
    Returns:
        Hex color code or None if not found
    """
    return COLOR_PALETTE.get(name.lower())

def get_severity_color(severity: str) -> str:
    """
    Get color for severity level.
    
    Args:
        severity: Severity level (critical, high, medium, low, info, etc.)
        
    Returns:
        Hex color code for the severity level
    """
    return SEVERITY_COLORS.get(severity.lower(), COLOR_PALETTE['light_yellow'])

def get_message_type_color(message_type: str) -> str:
    """
    Get color for message type.
    
    Args:
        message_type: Type of message (header, success, warning, etc.)
        
    Returns:
        Hex color code for the message type
    """
    return MESSAGE_TYPE_COLORS.get(message_type.lower(), COLOR_PALETTE['light_yellow'])

def format_hex_to_rgb(hex_code: str) -> Tuple[int, int, int]:
    """
    Convert hex color code to RGB tuple.
    
    Args:
        hex_code: Hex color code (e.g., '#FFFFB8')
        
    Returns:
        RGB tuple (r, g, b)
    """
    hex_code = hex_code.lstrip('#')
    return tuple(int(hex_code[i:i+2], 16) for i in (0, 2, 4))

def format_hex_to_ansi256(hex_code: str) -> int:
    """
    Convert hex color code to approximate ANSI 256-color code.
    This is a fallback for terminals without true-color support.
    
    Args:
        hex_code: Hex color code
        
    Returns:
        ANSI 256-color code
    """
    r, g, b = format_hex_to_rgb(hex_code)
    # Approximate RGB to ANSI 256-color
    if r == g == b:
        # Grayscale
        gray = round((r / 255.0) * 23)
        return 232 + gray
    else:
        # Color cube (6x6x6)
        r_idx = round((r / 255.0) * 5)
        g_idx = round((g / 255.0) * 5)
        b_idx = round((b / 255.0) * 5)
        return 16 + (r_idx * 36) + (g_idx * 6) + b_idx
