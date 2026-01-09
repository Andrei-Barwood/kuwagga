"""
Utility modules for macOS Threat Detection & Response Framework (MTDRF)
"""

from .permissions import check_admin_privileges, get_capabilities
from .colors import COLOR_PALETTE, get_color, get_severity_color
from .output import (
    print_cli, print_json, format_report,
    print_success, print_warning, print_error, print_info, print_debug
)
from .system_info import get_system_serial, get_mac_version, get_user_info

__all__ = [
    'check_admin_privileges',
    'get_capabilities',
    'COLOR_PALETTE',
    'get_color',
    'get_severity_color',
    'print_cli',
    'print_json',
    'format_report',
    'print_success',
    'print_warning',
    'print_error',
    'print_info',
    'print_debug',
    'get_system_serial',
    'get_mac_version',
    'get_user_info',
]
