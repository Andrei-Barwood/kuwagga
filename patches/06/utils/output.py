#!/usr/bin/env python3
"""
CLI and JSON output formatters for macOS Threat Detection & Response Framework (MTDRF)

Author: ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ
Owner: Snocomm. - 2026
"""

import json
import sys
from datetime import datetime
from typing import Any, Dict, List, Optional, Union

try:
    from rich.console import Console
    from rich.progress import Progress, BarColumn, TextColumn
    from rich.text import Text
    from rich.panel import Panel
    from rich.table import Table
    from rich import box
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False
    try:
        import colorama
        colorama.init()
        COLORAMA_AVAILABLE = True
    except ImportError:
        COLORAMA_AVAILABLE = False

from .colors import (
    get_severity_color, get_message_type_color,
    format_hex_to_rgb, format_hex_to_ansi256
)
import sys
from pathlib import Path
# Add parent directory to path for config import
sys.path.insert(0, str(Path(__file__).parent.parent))
import config

# Initialize console
if RICH_AVAILABLE:
    console = Console()
else:
    console = None

def _check_color_enabled() -> bool:
    """Check if color output is enabled."""
    return config.OUTPUT_CONFIG.get('use_colors', True) and (
        RICH_AVAILABLE or COLORAMA_AVAILABLE
    )

def _rich_style_from_hex(hex_code: str) -> str:
    """Convert hex color to Rich style string."""
    if not RICH_AVAILABLE:
        return ""
    try:
        r, g, b = format_hex_to_rgb(hex_code)
        return f"rgb({r},{g},{b})"
    except Exception:
        return ""

def print_cli(message: str, level: str = "info", color_code: Optional[str] = None) -> None:
    """
    Print colored CLI output using custom palette.
    
    Args:
        message: Message to print
        level: Severity level (critical, high, medium, low, info, success, warning, error, debug)
        color_code: Optional hex color code to override default
    """
    if not _check_color_enabled():
        print(message)
        return
    
    if color_code:
        color = color_code
    else:
        color = get_severity_color(level)
    
    if RICH_AVAILABLE:
        style = _rich_style_from_hex(color)
        if style:
            console.print(message, style=style)
        else:
            console.print(message)
    elif COLORAMA_AVAILABLE:
        # Fallback to colorama with ANSI 256 colors
        ansi_code = format_hex_to_ansi256(color)
        print(f"\033[38;5;{ansi_code}m{message}\033[0m")
    else:
        print(message)

def print_success(message: str) -> None:
    """Print success message."""
    print_cli(message, level="success", color_code=get_message_type_color("success"))

def print_warning(message: str) -> None:
    """Print warning message."""
    print_cli(message, level="warning", color_code=get_message_type_color("warning"))

def print_error(message: str) -> None:
    """Print error message."""
    print_cli(message, level="error", color_code=get_message_type_color("error"))

def print_info(message: str) -> None:
    """Print info message."""
    print_cli(message, level="info", color_code=get_message_type_color("info"))

def print_debug(message: str) -> None:
    """Print debug message."""
    if config.OUTPUT_CONFIG.get('verbose', False):
        print_cli(message, level="debug", color_code=get_message_type_color("debug"))

def print_header(text: str, color: Optional[str] = None) -> None:
    """
    Print section header with custom color.
    
    Args:
        text: Header text
        color: Optional hex color code, defaults to header color
    """
    if not color:
        color = get_message_type_color("header")
    
    if RICH_AVAILABLE:
        style = _rich_style_from_hex(color)
        panel = Panel(text, box=box.ROUNDED, style=style)
        console.print(panel)
    else:
        print_cli(f"\n{'='*60}\n{text}\n{'='*60}\n", color_code=color)

def print_json(data: Any, indent: int = 2) -> None:
    """
    Print data as formatted JSON.
    
    Args:
        data: Data to serialize to JSON
        indent: JSON indentation level
    """
    output_file = config.OUTPUT_CONFIG.get('output_file')
    json_str = json.dumps(data, indent=indent, default=str)
    
    if output_file:
        with open(output_file, 'w') as f:
            f.write(json_str)
        print_info(f"Output written to {output_file}")
    else:
        print(json_str)

def format_report(results: Dict[str, Any]) -> str:
    """
    Format detection results as a human-readable report.
    
    Args:
        results: Dictionary containing detection results
        
    Returns:
        Formatted report string
    """
    if not RICH_AVAILABLE:
        # Fallback to plain text formatting
        lines = []
        lines.append("=" * 60)
        lines.append("MTDRF Detection Report")
        lines.append("=" * 60)
        lines.append(f"Generated: {datetime.now().isoformat()}")
        lines.append("")
        
        for section, data in results.items():
            lines.append(f"\n{section.upper()}:")
            lines.append("-" * 40)
            if isinstance(data, list):
                for item in data:
                    lines.append(f"  - {item}")
            elif isinstance(data, dict):
                for key, value in data.items():
                    lines.append(f"  {key}: {value}")
            else:
                lines.append(f"  {data}")
        
        return "\n".join(lines)
    
    # Rich formatting
    table = Table(title="MTDRF Detection Report", box=box.ROUNDED)
    table.add_column("Section", style=_rich_style_from_hex(get_message_type_color("header")))
    table.add_column("Details", style=_rich_style_from_hex(get_message_type_color("info")))
    
    for section, data in results.items():
        if isinstance(data, list):
            data_str = "\n".join([f"• {item}" for item in data])
        elif isinstance(data, dict):
            data_str = "\n".join([f"{k}: {v}" for k, v in data.items()])
        else:
            data_str = str(data)
        
        severity = data.get('severity', 'info') if isinstance(data, dict) else 'info'
        color = get_severity_color(severity)
        table.add_row(section, data_str, style=_rich_style_from_hex(color))
    
    return table

def progress_bar(current: int, total: int, description: str = "Processing", color: Optional[str] = None) -> None:
    """
    Display progress bar with custom colors.
    
    Args:
        current: Current progress value
        total: Total value
        description: Description text
        color: Optional hex color code
    """
    if not color:
        color = get_message_type_color("primary_action")
    
    if RICH_AVAILABLE and console:
        with Progress(
            TextColumn(f"[{_rich_style_from_hex(color)}]{description}[/]"),
            BarColumn(),
            TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
            console=console
        ) as progress:
            task = progress.add_task(description, total=total)
            progress.update(task, completed=current)
    else:
        # Simple progress bar
        percentage = int((current / total) * 100) if total > 0 else 0
        bar_length = 40
        filled = int(bar_length * current / total) if total > 0 else 0
        bar = '=' * filled + '-' * (bar_length - filled)
        print(f"\r{description}: [{bar}] {percentage}%", end='', flush=True)
        if current >= total:
            print()  # New line when complete

def format_timestamp() -> str:
    """Get formatted timestamp."""
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def format_path(path: str) -> str:
    """Format file path with color."""
    color = get_message_type_color("path")
    if RICH_AVAILABLE:
        style = _rich_style_from_hex(color)
        return f"[{style}]{path}[/]"
    else:
        return path
