#!/usr/bin/env python3
"""
lurssen-mono-breakcore

Professional CLI tool to batch-process a full music discography to true mono
M4A (AAC) or WAV at 48 kHz using the Lurssen Mastering Console AU plugin
(via pedalboard) with breakcore-optimized settings, or a high-quality ffmpeg
emulation fallback.

Optimized for breakcore / aggressive electronic music:
- Transient punch and rhythmic clarity preserved in mono
- Moderate drive + push for glue and aggression without heavy squashing
- Presence boost in the 2.5-4.5 kHz range
- Dynamics respected — no default broadcast loudness normalization

Primary path: IK Multimedia Lurssen Mastering Console (or Lurssen Mastering EQ) Audio Unit
Fallback: Carefully tuned ffmpeg filter chain that approximates the Lurssen character.

Output formats (48 kHz mono):
- m4a — High-quality AAC (256–320 kbps) for distribution / listening
- wav — PCM WAV (16- or 24-bit) for DAW work, further production, archival

Input formats: .wav, .aiff, .flac, .m4a, .mp3, .opus (and a few aliases). Compressed formats (mp3, m4a, opus, etc.) are reliably decoded via ffmpeg before plugin processing.

Author: Expert audio + senior Python tooling
"""

import argparse
import logging
import os
import shutil
import subprocess
import sys
import tempfile
import uuid
import re
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import yaml
from tqdm import tqdm

try:
    import pedalboard
    from pedalboard.io import AudioFile
except ImportError as e:
    print("ERROR: pedalboard is required. pip install pedalboard", file=sys.stderr)
    raise

# --------------------------------------------------------------------------------------
# Constants & Defaults
# --------------------------------------------------------------------------------------

SUPPORTED_EXTS: set[str] = {".wav", ".wave", ".aiff", ".aif", ".flac", ".m4a", ".mp3", ".opus"}
DEFAULT_SUFFIX = "_MONO_LURSSEN_BREAKCORE"
DEFAULT_BITRATE = "320k"
DEFAULT_TRUE_PEAK = -1.0
DEFAULT_OUTPUT_FORMAT = "m4a"
SUPPORTED_OUTPUT_FORMATS: Tuple[str, ...] = ("m4a", "wav")
DEFAULT_WAV_BIT_DEPTH = 24
SUPPORTED_WAV_BIT_DEPTHS: Tuple[int, ...] = (16, 24)
# How deep below the input root we list folders for interactive selection
MAX_SELECT_FOLDER_DEPTH = 4


def is_supported_audio_file(path: Path) -> bool:
    """True for real audio files we can process.

    Skips AppleDouble resource-fork sidecars (._*) that macOS writes on
    non-APFS/HFS volumes (exFAT/FAT/NTFS external drives). Those files keep
    the original extension (e.g. ._track.flac) but are not audio — they only
    make pedalboard/ffmpeg fail with 'plugin processing failed'.
    Also skips other hidden/dotfiles.
    """
    name = path.name
    if name.startswith("._") or name.startswith("."):
        return False
    return path.is_file() and path.suffix.lower() in SUPPORTED_EXTS

# Breakcore-friendly starting point (tune to taste)
BREAKCORE_DEFAULTS: Dict[str, Any] = {
    "preset": "Electronic",
    "input_drive": 4.8,
    "push": 3.2,
    "presence": 3.5,
}

# --------------------------------------------------------------------------------------
# Suggested Profiles & Interactive Menu
# All the things users previously had to manually figure out / type are now suggested here.
# --------------------------------------------------------------------------------------

INTERACTIVE_PROFILES: List[Dict[str, Any]] = [
    {
        "name": "Balanced Breakcore (recommended)",
        "settings": {"preset": "Electronic", "input_drive": 4.8, "push": 3.2, "presence": 3.5},
        "desc": "Punchy transients, rhythmic clarity, moderate glue. Best default for most breakcore.",
    },
    {
        "name": "Aggressive Breakcore",
        "settings": {"preset": "Electronic", "input_drive": 5.7, "push": 3.9, "presence": 4.3},
        "desc": "More saturation + energy. Ideal for dense, noisy, or very chaotic material.",
    },
    {
        "name": "Heavy Glue & Push",
        "settings": {"preset": "More Glue", "input_drive": 5.2, "push": 4.5, "presence": 3.0},
        "desc": "Stronger analog-style glue. Use when you want tracks to feel cohesive.",
    },
    {
        "name": "Clarity & Air (lighter)",
        "settings": {"preset": "EDM", "input_drive": 3.8, "push": 2.8, "presence": 4.8},
        "desc": "Lower drive, higher presence emphasis. Helps complex breaks cut through in mono.",
    },
    {
        "name": "Emulation Only (ffmpeg, no AU plugin)",
        "settings": {"preset": None, "input_drive": 4.8, "push": 3.2, "presence": 3.5},
        "desc": "High-quality built-in ffmpeg chain. Select this if no Lurssen AU or you want to compare.",
        "force_no_plugin": True,
    },
    {
        "name": "Custom values...",
        "settings": None,
        "desc": "Enter your own numbers for drive / push / presence.",
    },
]

LOUDNESS_OPTIONS: List[Tuple[str, Optional[float]]] = [
    ("Disabled (recommended — preserves breakcore dynamics)", None),
    ("-14 LUFS (common for streaming platforms)", -14.0),
    ("-12 LUFS (louder)", -12.0),
    ("-10 LUFS (very loud)", -10.0),
    ("-8 LUFS (maximum aggression)", -8.0),
    ("Custom LUFS value...", "custom"),
]

BITRATE_OPTIONS = ["256k", "320k"]
OUTPUT_FORMAT_OPTIONS = ["m4a", "wav"]
WAV_BIT_DEPTH_OPTIONS = ["24", "16"]


def normalize_output_format(value: Any, default: str = DEFAULT_OUTPUT_FORMAT) -> str:
    """Normalize user/config format string to a supported value (m4a|wav)."""
    if value is None:
        return default
    fmt = str(value).strip().lower().lstrip(".")
    if fmt in ("wave",):
        fmt = "wav"
    if fmt in ("aac", "mp4"):
        fmt = "m4a"
    if fmt not in SUPPORTED_OUTPUT_FORMATS:
        logging.warning(
            f"Unknown output_format '{value}' — falling back to '{default}'. "
            f"Supported: {', '.join(SUPPORTED_OUTPUT_FORMATS)}"
        )
        return default
    return fmt


def normalize_wav_bit_depth(value: Any, default: int = DEFAULT_WAV_BIT_DEPTH) -> int:
    """Normalize bit depth for PCM WAV output (16 or 24)."""
    if value is None:
        return default
    try:
        depth = int(value)
    except (TypeError, ValueError):
        logging.warning(f"Invalid wav_bit_depth '{value}' — using {default}")
        return default
    if depth not in SUPPORTED_WAV_BIT_DEPTHS:
        logging.warning(
            f"Unsupported wav_bit_depth {depth} — using {default}. "
            f"Supported: {', '.join(str(d) for d in SUPPORTED_WAV_BIT_DEPTHS)}"
        )
        return default
    return depth


def output_extension(output_format: str) -> str:
    """File extension including the leading dot for the chosen output format."""
    fmt = normalize_output_format(output_format)
    return ".wav" if fmt == "wav" else ".m4a"


def wav_pcm_codec(bit_depth: int) -> str:
    """ffmpeg audio codec name for PCM WAV at the given bit depth."""
    depth = normalize_wav_bit_depth(bit_depth)
    return "pcm_s16le" if depth == 16 else "pcm_s24le"


def _get_questionary():
    """Return questionary module or None (graceful fallback to plain input)."""
    try:
        import questionary
        return questionary
    except ImportError:
        return None


def _prompt_text(message: str, default: Optional[str] = None) -> Optional[str]:
    q = _get_questionary()
    if q:
        try:
            return q.text(message, default=default or "").ask()
        except Exception:
            pass
    # Fallback
    d = f" (default: {default})" if default else ""
    val = input(f"{message}{d}: ").strip()
    return val if val else default


def _sanitize_user_path(p: Optional[str]) -> Optional[str]:
    """Strip surrounding quotes and whitespace. Users frequently paste paths with ' or " from shells / finders.
    Also recovers inner absolute path if a previous mangled (cwd + 'quoted') value was stored.
    """
    if p is None:
        return None
    s = str(p).strip()
    # repeatedly strip any outer matching quotes + ws
    for _ in range(4):
        s = s.strip()
        if len(s) >= 2 and s[0] == s[-1] and s[0] in ("'", '"'):
            s = s[1:-1]
        else:
            break
    # Recovery for previously-mangled values like: /repo/'/Volumes/xxx  or /repo/"/vol
    # Pull out the first absolute subpath that follows a quote.
    if "'" in s or '"' in s:
        m = re.search(r"['\"](/[^'\"]+)", s)
        if m:
            candidate = m.group(1)
            # Heuristic: looks like a plausible root on macOS or unix
            if candidate.startswith(("/", "/Volumes/", "/Users/", "/home/")) and len(candidate) > 2:
                s = candidate
    return s or None


def _prompt_path(message: str, default: Optional[str] = None, only_directories: bool = True) -> Optional[str]:
    q = _get_questionary()
    if q:
        try:
            raw = q.path(
                message,
                default=default or "",
                only_directories=only_directories,
            ).ask()
            return _sanitize_user_path(raw) or (default if default else None)
        except Exception:
            pass
    # Fallback
    d = f" [{default}]" if default else ""
    val = input(f"{message}{d}: ").strip()
    return _sanitize_user_path(val) or default


def _confirm(message: str, default: bool = True) -> bool:
    q = _get_questionary()
    if q:
        try:
            return bool(q.confirm(message, default=default).ask())
        except Exception:
            pass
    yn = "Y/n" if default else "y/N"
    val = input(f"{message} [{yn}]: ").strip().lower()
    if not val:
        return default
    return val.startswith("y")


def _select(
    message: str,
    choices: List[str],
    default: Optional[str] = None,
    *,
    numbered: Optional[bool] = None,
) -> Optional[str]:
    """Select one item from a list.

    For long menus (or when numbered=True) we use an explicit number prompt.
    Arrow-key UIs (questionary/prompt_toolkit) often mis-handle tall lists:
    after moving to item N and pressing Enter, the pointer can snap back to
    item 1 — especially when a large summary was printed above the list.
    Numbered selection is unambiguous and stable in every terminal.
    """
    if not choices:
        return None

    # Auto: number prompts for longer menus; keep short lists arrow-friendly
    if numbered is None:
        numbered = len(choices) > 6

    # Resolve default index for display / prefill
    default_idx: Optional[int] = None
    if default is not None:
        try:
            default_idx = choices.index(default)
        except ValueError:
            default_idx = None

    if numbered:
        return _select_numbered(message, choices, default_idx=default_idx)

    q = _get_questionary()
    if q:
        try:
            # use_shortcuts so typing 1..n moves the pointer; arrows still work
            kwargs: Dict[str, Any] = {
                "message": message,
                "choices": choices,
                "use_shortcuts": len(choices) <= 36,
                "use_arrow_keys": True,
                "use_jk_keys": len(choices) <= 19,  # avoid clash with auto shortcut 'j'/'k'
                "instruction": "(↑/↓ or number, Enter to confirm)",
            }
            if default is not None and default in choices:
                kwargs["default"] = default
            result = q.select(**kwargs).ask()
            return result
        except Exception:
            pass
    return _select_numbered(message, choices, default_idx=default_idx)


def _select_numbered(
    message: str,
    choices: List[str],
    default_idx: Optional[int] = None,
) -> Optional[str]:
    """Rock-solid numbered menu: print list, ask for a number, return choice."""
    print(f"\n{message}")
    width = len(str(len(choices)))
    for i, c in enumerate(choices, 1):
        mark = " *" if default_idx is not None and (i - 1) == default_idx else "  "
        print(f" {mark}{i:>{width}}. {c}")

    default_num = (default_idx + 1) if default_idx is not None else None
    hint = f"1–{len(choices)}"
    if default_num is not None:
        hint += f", Enter keeps {default_num}"

    q = _get_questionary()
    while True:
        raw: Optional[str]
        if q:
            try:
                raw = q.text(
                    f"Number ({hint})",
                    default=str(default_num) if default_num is not None else "",
                ).ask()
            except (KeyboardInterrupt, EOFError):
                return None
            except Exception:
                raw = None
                q = None  # fall through to plain input
            if raw is None and q is not None:
                # questionary cancel (Esc / Ctrl+C depending on version)
                return None
        if not q:
            try:
                shown = f"Enter number ({hint}): "
                raw = input(shown).strip()
            except (EOFError, KeyboardInterrupt):
                return None

        raw_s = str(raw if raw is not None else "").strip()
        if not raw_s and default_idx is not None:
            return choices[default_idx]
        try:
            idx = int(raw_s) - 1
            if 0 <= idx < len(choices):
                return choices[idx]
        except ValueError:
            pass
        print(f"  Invalid choice. Type a number between 1 and {len(choices)}.")


def _checkbox(
    message: str,
    choices: List[str],
    checked: Optional[List[str]] = None,
) -> Optional[List[str]]:
    """Multi-select menu. Returns selected choice strings, empty list if none, or None if cancelled."""
    if not choices:
        print("(nothing to select)")
        return []
    checked = checked or []
    q = _get_questionary()
    if q:
        try:
            # questionary.Choice supports checked=True for pre-selection
            q_choices = [
                q.Choice(title=c, checked=(c in checked))
                for c in choices
            ]
            result = q.checkbox(
                message + "  (space=toggle, a=all, enter=confirm)",
                choices=q_choices,
            ).ask()
            # None = cancelled (Ctrl+C / Esc depending on version)
            return result if result is not None else None
        except Exception:
            pass
    # Numbered fallback: comma-separated indices, ranges, all, none
    print(f"\n{message}")
    print("  Enter numbers (e.g. 1,3,5-8), 'all', or 'none'. Prefixed * = currently selected.")
    for i, c in enumerate(choices, 1):
        mark = " *" if c in checked else "  "
        print(f" {mark}{i}. {c}")
    while True:
        raw = input("Selection: ").strip().lower()
        if not raw:
            # keep previous selection if any, else empty
            return list(checked) if checked else []
        if raw in ("none", "n", "0"):
            return []
        if raw in ("all", "a", "*"):
            return list(choices)
        selected_idx: set[int] = set()
        try:
            for part in raw.replace(" ", "").split(","):
                if not part:
                    continue
                if "-" in part:
                    a, b = part.split("-", 1)
                    start, end = int(a), int(b)
                    if start > end:
                        start, end = end, start
                    for n in range(start, end + 1):
                        selected_idx.add(n - 1)
                else:
                    selected_idx.add(int(part) - 1)
            out = [choices[i] for i in sorted(selected_idx) if 0 <= i < len(choices)]
            if out or raw:
                return out
        except Exception:
            pass
        print("Invalid selection. Examples: 1,2,5  |  1-4  |  all  |  none")


def _prompt_float(message: str, default: Optional[float] = None, min_val: Optional[float] = None, max_val: Optional[float] = None) -> Optional[float]:
    q = _get_questionary()
    if q:
        try:
            val = q.text(
                f"{message} (current: {default})",
                default=str(default) if default is not None else "",
            ).ask()
            if val is None:
                return default
            fval = float(val)
            if (min_val is not None and fval < min_val) or (max_val is not None and fval > max_val):
                print(f"Clamped to valid range [{min_val}, {max_val}]")
                fval = max(min_val or fval, min(max_val or fval, fval))
            return fval
        except Exception:
            pass
    # Fallback
    d = f" [{default}]" if default is not None else ""
    while True:
        val = input(f"{message}{d}: ").strip()
        if not val:
            return default
        try:
            fval = float(val)
            if (min_val is not None and fval < min_val) or (max_val is not None and fval > max_val):
                print("Value outside suggested range, using anyway.")
            return fval
        except ValueError:
            print("Please enter a number.")


def select_mastering_profile() -> Dict[str, Any]:
    """Present the suggested intuitive configurations."""
    choices = [f"{p['name']} — {p['desc']}" for p in INTERACTIVE_PROFILES]
    sel = _select("Select a suggested mastering profile (these encode the recommended breakcore settings):", choices)

    for p in INTERACTIVE_PROFILES:
        if sel and p["name"] in sel:
            if p["settings"] is None:
                # Custom flow
                return prompt_custom_breakcore_settings()
            result = dict(p["settings"])
            if p.get("force_no_plugin"):
                result["force_no_plugin"] = True
            return result
    return dict(INTERACTIVE_PROFILES[0]["settings"])


def prompt_custom_breakcore_settings() -> Dict[str, Any]:
    print("\nCustom breakcore parameters (typical ranges shown):")
    drive = _prompt_float("Input Drive (aggression/glue, ~3.5–6.5)", default=4.8, min_val=0.0, max_val=12.0)
    push = _prompt_float("Push (energy/presence, ~2.0–5.0)", default=3.2, min_val=0.0, max_val=8.0)
    pres = _prompt_float("Presence ~3-4kHz emphasis (~2.5–5.5)", default=3.5, min_val=0.0, max_val=8.0)
    preset = _select("Preset name (if plugin supports it):", ["Electronic", "EDM", "More Glue", "None / Default"])
    if preset == "None / Default":
        preset = None
    return {"preset": preset, "input_drive": drive, "push": push, "presence": pres}


def select_loudness_target(current: Optional[float]) -> Optional[float]:
    choices = [label for (label, _) in LOUDNESS_OPTIONS]
    sel = _select("Loudness target (LUFS). For breakcore we usually recommend DISABLED:", choices)
    for label, val in LOUDNESS_OPTIONS:
        if sel and label in sel:
            if val == "custom":
                return _prompt_float("Enter custom LUFS target (negative number)", default=-14.0, max_val=-1.0)
            return val
    return current


def configure_plugin_path(current_path: Optional[str]) -> Tuple[Optional[str], bool]:
    """Let user pick how to handle the Lurssen plugin."""
    q = _get_questionary()
    detected = find_lurssen_plugin(None)
    detected_str = str(detected) if detected else "not found"

    options = [
        f"Auto-detect (currently: {detected_str})",
        "Enter / paste full path manually",
        "Disable plugin — use ffmpeg emulation only",
    ]
    if current_path:
        options.append(f"Keep current: {current_path}")

    choice = _select("Lurssen plugin configuration:", options)

    if not choice:
        return current_path, True

    if "Auto-detect" in choice:
        return (str(detected) if detected else None), True
    elif "Enter / paste" in choice:
        p = _prompt_path("Full path to .component bundle", default=current_path, only_directories=False)
        p = _sanitize_user_path(p)
        return (p if p else current_path), True
    elif "Disable plugin" in choice:
        return None, False
    elif "Keep current" in choice:
        return current_path, True
    return current_path, True


# --------------------------------------------------------------------------------------
# Folder / file selection (interactive control over what gets converted)
# --------------------------------------------------------------------------------------

def list_folders_up_to_depth(root: Path, max_depth: int = MAX_SELECT_FOLDER_DEPTH) -> List[Path]:
    """
    Return [root] + every subdirectory under root whose depth is <= max_depth.
    Depth 1 = immediate children of root, depth 4 = four levels below root.
    Skips hidden directories (name starts with '.').
    """
    root = root.expanduser().resolve()
    folders: List[Path] = [root]
    if max_depth < 1:
        return folders

    # os.walk with depth limit is faster / more reliable than nested rglob for large trees
    root_parts = len(root.parts)
    for dirpath, dirnames, _filenames in os.walk(root):
        # Always resolve so macOS /var vs /private/var stays consistent
        dir_path = Path(dirpath).resolve()
        rel_depth = len(dir_path.parts) - root_parts
        # dirnames are children of dirpath → their depth is rel_depth + 1
        keep: List[str] = []
        for name in sorted(dirnames):
            if name.startswith("."):
                continue
            child_depth = rel_depth + 1
            if child_depth > max_depth:
                continue
            keep.append(name)
            folders.append((dir_path / name).resolve())
        dirnames[:] = keep  # prune os.walk descent beyond max_depth
        if rel_depth >= max_depth:
            dirnames[:] = []
    # stable unique order: root first, then relative path sort
    seen: set[Path] = set()
    ordered: List[Path] = []
    for f in folders:
        rf = f.resolve()
        if rf not in seen:
            seen.add(rf)
            ordered.append(rf)
    ordered[1:] = sorted(ordered[1:], key=lambda p: str(p.relative_to(root)).lower())
    return ordered


def count_audio_files_in_folder(folder: Path, recursive: bool = True) -> int:
    """Count supported audio files directly in folder, or recursively under it."""
    if not folder.is_dir():
        return 0
    n = 0
    if recursive:
        for p in folder.rglob("*"):
            if is_supported_audio_file(p):
                n += 1
    else:
        for p in folder.iterdir():
            if is_supported_audio_file(p):
                n += 1
    return n


def list_audio_files_in_folders(folders: List[Path], input_root: Path) -> List[Path]:
    """Union of audio files under any of the given folders, de-duplicated, sorted."""
    input_root = input_root.resolve()
    found: set[Path] = set()
    for folder in folders:
        folder = folder.resolve()
        if not folder.exists():
            continue
        # If folder is outside root, still scan it; otherwise prefer rglob under folder
        for p in folder.rglob("*"):
            if is_supported_audio_file(p):
                found.add(p.resolve())
    return sorted(found, key=lambda p: str(p).lower())


def _folder_label(folder: Path, root: Path, file_count: int) -> str:
    """Human-readable label for checkbox: relative path + track count."""
    try:
        rel = folder.resolve().relative_to(root.resolve())
        path_str = "." if str(rel) == "." else str(rel)
    except ValueError:
        path_str = str(folder)
    depth = 0 if path_str == "." else len(Path(path_str).parts)
    indent = "  " * min(depth, MAX_SELECT_FOLDER_DEPTH)
    tracks = f"{file_count} track" + ("" if file_count == 1 else "s")
    if path_str == ".":
        return f"{indent}[root]  ({tracks} under this tree)"
    return f"{indent}{path_str}  ({tracks})"


def select_folders_and_files(input_root: Path, previous: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """
    Interactive menu: pick folders (up to MAX_SELECT_FOLDER_DEPTH levels) then files inside them.

    Returns:
      {
        "selected_folders": [rel posix paths under input_root, "." for root],
        "selected_files":   [rel posix paths of audio files],  # empty => no selection filter
        "selection_active": bool,  # True when user explicitly chose a subset
      }
    previous may contain earlier selection to pre-check items.
    """
    previous = previous or {}
    input_root = input_root.expanduser().resolve()
    if not input_root.is_dir():
        print(f"Input directory does not exist or is not a directory: {input_root}")
        return {
            "selected_folders": previous.get("selected_folders") or [],
            "selected_files": previous.get("selected_files") or [],
            "selection_active": bool(previous.get("selection_active")),
        }

    print(f"\nScanning folders under:\n  {input_root}")
    print(f"(up to {MAX_SELECT_FOLDER_DEPTH} subfolder levels)\n")

    folders = list_folders_up_to_depth(input_root, MAX_SELECT_FOLDER_DEPTH)
    # Only show folders that contain at least one audio file (recursive under that folder,
    # but still constrained by what exists on disk — scan is full under each node).
    # For performance we count once per folder.
    folder_counts: Dict[Path, int] = {}
    labeled: List[str] = []
    label_to_path: Dict[str, Path] = {}
    for folder in folders:
        # Count only files that are still within max depth from input_root when possible
        cnt = count_audio_files_in_folder(folder, recursive=True)
        folder_counts[folder] = cnt
        if cnt == 0 and folder != input_root:
            continue  # hide empty branches
        label = _folder_label(folder, input_root, cnt)
        # ensure unique labels
        if label in label_to_path:
            label = f"{label}  [{folder}]"
        labeled.append(label)
        label_to_path[label] = folder

    if not labeled:
        print("No audio files found under this input directory.")
        return {"selected_folders": [], "selected_files": [], "selection_active": False}

    # Pre-check from previous selection
    prev_folders = set(previous.get("selected_folders") or [])
    prechecked_labels: List[str] = []
    if previous.get("selection_active") and prev_folders:
        for lab, path in label_to_path.items():
            try:
                rel = path.relative_to(input_root)
                rel_s = "." if str(rel) == "." else rel.as_posix()
            except ValueError:
                rel_s = str(path)
            if rel_s in prev_folders:
                prechecked_labels.append(lab)

    mode = _select(
        "How do you want to choose content to convert?",
        [
            "Select folders (then optionally pick files inside)",
            "Select individual files across the whole tree",
            "Process EVERYTHING under input dir (clear selection)",
            "Keep current selection (cancel)",
        ],
    )

    if not mode or "Keep current" in mode:
        return {
            "selected_folders": list(previous.get("selected_folders") or []),
            "selected_files": list(previous.get("selected_files") or []),
            "selection_active": bool(previous.get("selection_active")),
        }

    if "EVERYTHING" in mode or "clear selection" in mode.lower():
        print("Selection cleared — all audio under the input directory will be processed.")
        return {"selected_folders": [], "selected_files": [], "selection_active": False}

    selected_folder_paths: List[Path] = []
    selected_file_paths: List[Path] = []

    if mode.startswith("Select folders"):
        chosen_labels = _checkbox(
            "Select folders / subfolders to include (space toggles):",
            labeled,
            checked=prechecked_labels or None,
        )
        if chosen_labels is None:
            print("Folder selection cancelled.")
            return {
                "selected_folders": list(previous.get("selected_folders") or []),
                "selected_files": list(previous.get("selected_files") or []),
                "selection_active": bool(previous.get("selection_active")),
            }
        if not chosen_labels:
            print("No folders selected. Selection cleared.")
            return {"selected_folders": [], "selected_files": [], "selection_active": False}

        selected_folder_paths = [label_to_path[lab] for lab in chosen_labels if lab in label_to_path]
        # De-duplicate nested: if both parent and child selected, keep both for labels but union files
        candidate_files = list_audio_files_in_folders(selected_folder_paths, input_root)
        if not candidate_files:
            print("Selected folders contain no supported audio files.")
            return {"selected_folders": [], "selected_files": [], "selection_active": False}

        refine = _select(
            f"{len(candidate_files)} track(s) in selected folder(s). Refine file list?",
            [
                f"Convert ALL {len(candidate_files)} files in selected folders",
                "Pick specific files inside the selected folders",
            ],
        )
        if refine and refine.startswith("Pick specific"):
            file_labels: List[str] = []
            file_label_to_path: Dict[str, Path] = {}
            prev_files = set(previous.get("selected_files") or [])
            prechecked_files: List[str] = []
            for fp in candidate_files:
                try:
                    rel = fp.relative_to(input_root).as_posix()
                except ValueError:
                    rel = str(fp)
                file_labels.append(rel)
                file_label_to_path[rel] = fp
                if rel in prev_files:
                    prechecked_files.append(rel)
            picked = _checkbox(
                "Select files to convert:",
                file_labels,
                checked=prechecked_files or file_labels,  # default: all candidates checked
            )
            if picked is None:
                print("File selection cancelled — keeping folder-level selection (all files).")
                selected_file_paths = candidate_files
            elif not picked:
                print("No files selected. Selection cleared.")
                return {"selected_folders": [], "selected_files": [], "selection_active": False}
            else:
                selected_file_paths = [file_label_to_path[lab] for lab in picked if lab in file_label_to_path]
        else:
            selected_file_paths = candidate_files

    else:
        # Select individual files across the whole tree (still limited by folder depth for discovery
        # of which folders we walk — but files may sit deeper; we scan full tree under root for this mode)
        all_files = find_audio_files(input_root)
        if not all_files:
            print("No audio files found.")
            return {"selected_folders": [], "selected_files": [], "selection_active": False}

        # Optionally filter listing to files within max depth folders for sanity
        # (files deeper than max_depth are still listed so user has full control)
        file_labels = []
        file_label_to_path: Dict[str, Path] = {}
        prev_files = set(previous.get("selected_files") or [])
        prechecked_files = []
        for fp in all_files:
            try:
                rel = fp.relative_to(input_root).as_posix()
            except ValueError:
                rel = str(fp)
            file_labels.append(rel)
            file_label_to_path[rel] = fp
            if rel in prev_files:
                prechecked_files.append(rel)

        print(f"Found {len(file_labels)} audio file(s). Use space to toggle, enter to confirm.")
        picked = _checkbox(
            "Select individual files to convert:",
            file_labels,
            checked=prechecked_files or None,
        )
        if picked is None:
            print("File selection cancelled.")
            return {
                "selected_folders": list(previous.get("selected_folders") or []),
                "selected_files": list(previous.get("selected_files") or []),
                "selection_active": bool(previous.get("selection_active")),
            }
        if not picked:
            print("No files selected. Selection cleared.")
            return {"selected_folders": [], "selected_files": [], "selection_active": False}

        selected_file_paths = [file_label_to_path[lab] for lab in picked if lab in file_label_to_path]
        # Derive folder set from parent dirs of selected files (for summary)
        parents: set[Path] = set()
        for fp in selected_file_paths:
            parents.add(fp.parent.resolve())
        selected_folder_paths = sorted(parents)

    # Serialize relative paths for config / state
    sel_folders_rel: List[str] = []
    seen_f: set[str] = set()
    for folder in selected_folder_paths:
        try:
            rel = folder.resolve().relative_to(input_root)
            key = "." if str(rel) == "." else rel.as_posix()
        except ValueError:
            key = str(folder)
        if key not in seen_f:
            seen_f.add(key)
            sel_folders_rel.append(key)

    sel_files_rel: List[str] = []
    seen_files: set[str] = set()
    for fp in selected_file_paths:
        try:
            key = fp.resolve().relative_to(input_root).as_posix()
        except ValueError:
            key = str(fp)
        if key not in seen_files:
            seen_files.add(key)
            sel_files_rel.append(key)

    print(f"\nSelection locked in: {len(sel_files_rel)} file(s) from {len(sel_folders_rel)} folder(s).")
    # Show a short preview
    for rel in sel_files_rel[:8]:
        print(f"  • {rel}")
    if len(sel_files_rel) > 8:
        print(f"  … +{len(sel_files_rel) - 8} more")

    return {
        "selected_folders": sel_folders_rel,
        "selected_files": sel_files_rel,
        "selection_active": True,
    }


def resolve_selected_files(input_root: Path, selection: Dict[str, Any]) -> Optional[List[Path]]:
    """
    Turn stored selection into absolute Paths.
    Returns None when selection is inactive (caller should process entire tree).
    Returns empty list if active but nothing valid remains.
    """
    if not selection or not selection.get("selection_active"):
        return None
    input_root = input_root.expanduser().resolve()
    files_rel = selection.get("selected_files") or []
    out: List[Path] = []
    if files_rel:
        for rel in files_rel:
            p = (input_root / rel).resolve() if not Path(rel).is_absolute() else Path(rel).resolve()
            if is_supported_audio_file(p):
                out.append(p)
            elif p.is_file():
                logging.warning(f"Skipping unsupported file in selection: {p}")
            else:
                logging.warning(f"Selected file missing, skipped: {rel}")
        return sorted(set(out), key=lambda x: str(x).lower())

    # Folder-only selection (no explicit file list)
    folders_rel = selection.get("selected_folders") or []
    folder_paths: List[Path] = []
    for rel in folders_rel:
        if rel in (".", "", None):
            folder_paths.append(input_root)
        else:
            p = (input_root / rel).resolve() if not Path(str(rel)).is_absolute() else Path(rel).resolve()
            if p.is_dir():
                folder_paths.append(p)
    if not folder_paths:
        return []
    return list_audio_files_in_folders(folder_paths, input_root)


def show_summary(current: Dict[str, Any]) -> None:
    print("\n" + "=" * 62)
    print("  CURRENT SETTINGS (all manual CLI/config values in one place)")
    print("=" * 62)
    print(f"  Input dir       : {current.get('input_dir') or '(not set)'}")
    print(f"  Output dir      : {current.get('output_dir') or '(not set)'}")
    # Selection summary
    if current.get("selection_active") and current.get("selected_files"):
        n_files = len(current.get("selected_files") or [])
        n_folders = len(current.get("selected_folders") or [])
        print(f"  Content select  : {n_files} file(s) in {n_folders} folder(s)  [FILTER ON]")
        for rel in (current.get("selected_folders") or [])[:5]:
            print(f"                    folder: {rel}")
        if n_folders > 5:
            print(f"                    … +{n_folders - 5} more folders")
    elif current.get("selection_active") and current.get("selected_folders"):
        n_folders = len(current.get("selected_folders") or [])
        print(f"  Content select  : {n_folders} folder(s) selected  [FILTER ON]")
    else:
        print("  Content select  : ALL audio under input dir  [no filter]")
    print(f"  Plugin path     : {current.get('plugin_path') or '(auto / none)'}")
    print(f"  Use plugin      : {current.get('use_plugin', True)}")
    print(f"  Profile/preset  : {current.get('preset')}")
    print(f"  input_drive     : {current.get('input_drive')}")
    print(f"  push            : {current.get('push')}")
    print(f"  presence        : {current.get('presence')}")
    print(f"  loudness_target : {current.get('loudness_target') or 'DISABLED (recommended)'}")
    print(f"  true_peak       : {current.get('true_peak')}")
    out_fmt = normalize_output_format(current.get("output_format"))
    print(f"  output_format   : {out_fmt}")
    if out_fmt == "wav":
        print(f"  wav_bit_depth   : {normalize_wav_bit_depth(current.get('wav_bit_depth'))}")
    else:
        print(f"  bitrate         : {current.get('bitrate')}")
    print(f"  suffix          : {current.get('suffix')}")
    print(f"  jobs            : {current.get('jobs')}")
    print(f"  overwrite       : {current.get('overwrite')}")
    print(f"  verbose         : {current.get('verbose')}")
    print("=" * 62)
    print("  These are exactly the values you would otherwise set with many CLI flags or by editing YAML.\n")


def run_interactive_mode(initial_cfg: Dict[str, Any]) -> Dict[str, Any]:
    """Intuitive menu that surfaces every configuration option with sensible suggestions."""
    q = _get_questionary()
    if not q:
        print("Note: For the best arrow-key menu experience, install with `pip install questionary`.")
        print("Falling back to simple numbered prompts.\n")

    current: Dict[str, Any] = {
        "input_dir": _sanitize_user_path(initial_cfg.get("input_dir")),
        "output_dir": _sanitize_user_path(initial_cfg.get("output_dir")),
        "plugin_path": _sanitize_user_path(initial_cfg.get("plugin_path")),
        "use_plugin": resolve_value(None, initial_cfg.get("use_plugin"), True),
        "preset": resolve_value(None, initial_cfg.get("preset"), BREAKCORE_DEFAULTS["preset"]),
        "input_drive": resolve_value(None, initial_cfg.get("input_drive"), BREAKCORE_DEFAULTS["input_drive"]),
        "push": resolve_value(None, initial_cfg.get("push"), BREAKCORE_DEFAULTS["push"]),
        "presence": resolve_value(None, initial_cfg.get("presence"), BREAKCORE_DEFAULTS["presence"]),
        "loudness_target": initial_cfg.get("loudness_target"),
        "true_peak": resolve_value(None, initial_cfg.get("true_peak"), DEFAULT_TRUE_PEAK),
        "output_format": normalize_output_format(
            resolve_value(None, initial_cfg.get("output_format"), DEFAULT_OUTPUT_FORMAT)
        ),
        "wav_bit_depth": normalize_wav_bit_depth(
            resolve_value(None, initial_cfg.get("wav_bit_depth"), DEFAULT_WAV_BIT_DEPTH)
        ),
        "bitrate": resolve_value(None, initial_cfg.get("bitrate"), DEFAULT_BITRATE),
        "suffix": resolve_value(None, initial_cfg.get("suffix"), DEFAULT_SUFFIX),
        "jobs": resolve_value(None, initial_cfg.get("jobs"), 2),
        "overwrite": resolve_value(None, initial_cfg.get("overwrite"), False),
        "verbose": resolve_value(None, initial_cfg.get("verbose"), False),
        # Content selection (folders / files). Empty + inactive = process entire tree.
        "selected_folders": list(initial_cfg.get("selected_folders") or []),
        "selected_files": list(initial_cfg.get("selected_files") or []),
        "selection_active": bool(initial_cfg.get("selection_active", False)),
    }

    # Friendly first-run help
    if not current.get("input_dir"):
        print("\nWelcome to lurssen-mono-breakcore interactive setup!")
        print("This menu lets you pick from recommended configurations instead of remembering CLI flags.\n")

    # Auto-detect plugin once at start if missing
    if not current.get("plugin_path"):
        auto = find_lurssen_plugin(None)
        if auto:
            current["plugin_path"] = str(auto)
            print(f"Auto-detected Lurssen plugin: {auto.name}")

    # Remember last main-menu choice so reopening does not snap back to item 1
    last_main_choice: Optional[str] = None

    while True:
        show_summary(current)

        # Short, single-line labels (long wrapping titles confuse prompt_toolkit pointers)
        menu_choices = [
            "Set Input Directory",
            "Set Output Directory",
            "Select folders & files to convert",
            "Configure Lurssen Plugin Path / Mode",
            "Choose Suggested Mastering Profile",
            "Fine-tune Drive / Push / Presence",
            "Set Loudness Target & True Peak",
            "Output settings (format, bitrate/wav depth, suffix, jobs, overwrite)",
            "Toggle verbose logging",
            "Plugin tools (inspect parameters)",
            "Load settings from a YAML config file",
            "Save these settings to config.yaml",
            "Preview / dry-run scan",
            "START (dry-run only)",
            "START PROCESSING (real run)",
            "Exit menu (quit without running)",
        ]

        choice = _select(
            "Main menu — type the number of an action, then Enter:",
            menu_choices,
            default=last_main_choice if last_main_choice in menu_choices else None,
            numbered=True,
        )

        if not choice:
            continue

        last_main_choice = choice

        if choice.startswith("Set Input"):
            p = _prompt_path("Root input folder containing your albums / discography (absolute path e.g. /Volumes/Drive/...) ", current.get("input_dir"))
            p = _sanitize_user_path(p)
            if p:
                pth = Path(p).expanduser()
                if not pth.is_absolute():
                    print(f"  Note: relative path will resolve under CWD ({Path.cwd()})")
                expanded = pth.resolve()
                old_in = current.get("input_dir")
                current["input_dir"] = str(expanded)
                if not expanded.exists():
                    print(f"Note: {expanded} does not exist yet.")
                # Changing root invalidates a previous content selection
                if old_in and str(Path(old_in).expanduser().resolve()) != str(expanded):
                    if current.get("selection_active"):
                        print("Input directory changed — previous folder/file selection cleared.")
                    current["selected_folders"] = []
                    current["selected_files"] = []
                    current["selection_active"] = False

        elif choice.startswith("Set Output"):
            p = _prompt_path("Output folder (will be created, structure mirrored; absolute recommended e.g. /Volumes/Drive/OUT) ", current.get("output_dir"))
            p = _sanitize_user_path(p)
            if p:
                pth = Path(p).expanduser()
                if not pth.is_absolute():
                    print(f"  Note: relative path will resolve under CWD ({Path.cwd()})")
                current["output_dir"] = str(pth.resolve())

        elif "Select folders" in choice or "files to convert" in choice:
            if not current.get("input_dir"):
                print("Set input directory first (option 1), then select which folders/files to convert.")
                _confirm("Press Enter to return to the menu...", default=True)
                continue
            in_root = Path(current["input_dir"]).expanduser().resolve()
            if not in_root.exists():
                print(f"Input directory does not exist: {in_root}")
                print("Fix option 1 (Set Input Directory) — often the external volume is not mounted.")
                _confirm("Press Enter to return to the menu...", default=True)
                continue
            result = select_folders_and_files(
                in_root,
                previous={
                    "selected_folders": current.get("selected_folders") or [],
                    "selected_files": current.get("selected_files") or [],
                    "selection_active": current.get("selection_active"),
                },
            )
            current["selected_folders"] = result.get("selected_folders") or []
            current["selected_files"] = result.get("selected_files") or []
            current["selection_active"] = bool(result.get("selection_active"))

        elif "Configure Lurssen Plugin" in choice:
            new_path, use_plug = configure_plugin_path(current.get("plugin_path"))
            current["plugin_path"] = new_path
            current["use_plugin"] = use_plug

        elif "Choose Suggested Mastering Profile" in choice:
            prof = select_mastering_profile()
            if prof:
                for k in ("preset", "input_drive", "push", "presence"):
                    if k in prof and prof[k] is not None:
                        current[k] = prof[k]
                if prof.get("force_no_plugin"):
                    current["use_plugin"] = False
                    current["plugin_path"] = None
                print("Profile applied.")

        elif "Fine-tune Drive" in choice:
            current["input_drive"] = _prompt_float("Input Drive", default=current["input_drive"], min_val=0, max_val=12)
            current["push"] = _prompt_float("Push", default=current["push"], min_val=0, max_val=8)
            current["presence"] = _prompt_float("Presence", default=current["presence"], min_val=0, max_val=8)
            preset = _select("Preset (leave or change):", ["Electronic", "EDM", "More Glue", "Keep current"])
            if preset != "Keep current":
                current["preset"] = None if preset == "None" else preset

        elif "Set Loudness Target" in choice:
            current["loudness_target"] = select_loudness_target(current.get("loudness_target"))
            current["true_peak"] = _prompt_float("True peak ceiling (dBTP)", default=current.get("true_peak"), min_val=-6, max_val=-0.1)

        elif "Output settings" in choice:
            fmt_choice = _select(
                "Output format:",
                OUTPUT_FORMAT_OPTIONS,
                default=normalize_output_format(current.get("output_format")),
            )
            if fmt_choice:
                current["output_format"] = normalize_output_format(fmt_choice)
            if current.get("output_format") == "wav":
                depth_choice = _select(
                    "WAV bit depth (PCM):",
                    WAV_BIT_DEPTH_OPTIONS,
                    default=str(normalize_wav_bit_depth(current.get("wav_bit_depth"))),
                )
                if depth_choice:
                    current["wav_bit_depth"] = normalize_wav_bit_depth(depth_choice)
            else:
                br = _select("AAC bitrate:", BITRATE_OPTIONS, default=current.get("bitrate"))
                if br:
                    current["bitrate"] = br
            ext = output_extension(current.get("output_format", DEFAULT_OUTPUT_FORMAT))
            current["suffix"] = _prompt_text(
                f"Filename suffix (before {ext})",
                default=current.get("suffix"),
            )
            current["jobs"] = int(_prompt_float("Parallel jobs (1 safest, 2-4 good on Apple Silicon)", default=current.get("jobs"), min_val=1, max_val=8) or 1)
            current["overwrite"] = _confirm("Overwrite existing output files?", default=bool(current.get("overwrite")))

        elif "Toggle verbose" in choice:
            current["verbose"] = not current.get("verbose", False)
            print(f"Verbose is now {'ON' if current['verbose'] else 'OFF'}")

        elif "Plugin tools" in choice:
            plug = current.get("plugin_path") or find_lurssen_plugin(None)
            if plug:
                try:
                    show_plugin_info(Path(plug))
                except Exception as ex:
                    print(f"Could not inspect: {ex}")
            else:
                print("No plugin path. Use 'Configure Lurssen Plugin Path' first.")
            _confirm("Press enter to continue...", default=True)

        elif "Load settings from a YAML" in choice:
            cfg_path = _prompt_path("Path to config YAML to load", default="config.yaml", only_directories=False)
            if cfg_path:
                loaded = load_config(Path(cfg_path))
                if loaded:
                    for k in ("input_dir", "output_dir", "plugin_path", "use_plugin", "preset",
                              "input_drive", "push", "presence", "loudness_target", "true_peak",
                              "output_format", "wav_bit_depth",
                              "bitrate", "suffix", "jobs", "overwrite", "verbose",
                              "selected_folders", "selected_files", "selection_active"):
                        if k in loaded and loaded[k] is not None:
                            v = loaded[k]
                            if k in ("input_dir", "output_dir", "plugin_path"):
                                v = _sanitize_user_path(v)
                            current[k] = v
                    # Coerce list fields + output format
                    current["selected_folders"] = list(current.get("selected_folders") or [])
                    current["selected_files"] = list(current.get("selected_files") or [])
                    current["selection_active"] = bool(current.get("selection_active"))
                    current["output_format"] = normalize_output_format(current.get("output_format"))
                    current["wav_bit_depth"] = normalize_wav_bit_depth(current.get("wav_bit_depth"))
                    print("Loaded values from YAML (paths & settings merged).")

        elif "Save these settings" in choice:
            out_path = Path("config.yaml")
            try:
                to_save = {k: current.get(k) for k in (
                    "input_dir", "output_dir", "plugin_path", "use_plugin", "preset",
                    "input_drive", "push", "presence", "loudness_target", "true_peak",
                    "output_format", "wav_bit_depth",
                    "bitrate", "suffix", "jobs", "overwrite", "verbose",
                    "selected_folders", "selected_files", "selection_active",
                )}
                # Clean None for yaml niceness where sensible
                with open(out_path, "w", encoding="utf-8") as f:
                    yaml.safe_dump(to_save, f, sort_keys=False, default_flow_style=False)
                print(f"Saved to {out_path.resolve()}")
            except Exception as ex:
                print(f"Failed to save: {ex}")

        elif "Preview / dry-run" in choice:
            if not current.get("input_dir"):
                print("Set input directory first.")
                continue
            in_root = Path(current["input_dir"]).expanduser().resolve()
            if not in_root.exists():
                print("Input directory does not exist.")
                continue
            selected = resolve_selected_files(
                in_root,
                {
                    "selection_active": current.get("selection_active"),
                    "selected_folders": current.get("selected_folders"),
                    "selected_files": current.get("selected_files"),
                },
            )
            if selected is None:
                files = find_audio_files(in_root)
                scope = "entire input tree (no selection filter)"
            else:
                files = selected
                scope = "your folder/file selection"
            print(f"\nWould process {len(files)} audio file(s) — {scope}")
            print(f"  under: {in_root}")
            if files:
                print("First few:")
                for f in files[:12]:
                    try:
                        print(f"  - {f.relative_to(in_root)}")
                    except ValueError:
                        print(f"  - {f}")
                if len(files) > 12:
                    print(f"  ... + {len(files)-12} more")
            elif current.get("selection_active"):
                print("  (selection is active but resolved to zero files — re-run selection)")
            _confirm("Back to menu...", default=True)

        elif "START (dry-run only" in choice:
            if not current.get("input_dir") or not current.get("output_dir"):
                print("You must set both Input and Output directories before starting.")
                continue
            if not current.get("selection_active"):
                if not _confirm(
                    "No folder/file selection is set — process EVERYTHING under input dir?",
                    default=True,
                ):
                    print("Use 'Select folders & files to convert' first for full control.")
                    continue
            if _confirm("Perform a dry-run (list what would happen, make no changes)?", default=True):
                # Signal dry-run by adding a key that main() will pick up via monkey into args
                current["_dry_run"] = True
                return current

        elif "START PROCESSING (real run)" in choice:
            if not current.get("input_dir") or not current.get("output_dir"):
                print("You must set both Input and Output directories before starting.")
                continue
            if not current.get("selection_active"):
                if not _confirm(
                    "No folder/file selection is set — process EVERYTHING under input dir?",
                    default=True,
                ):
                    print("Use 'Select folders & files to convert' first for full control.")
                    continue
            if _confirm("Start batch processing now with the settings shown above?", default=True):
                current["_dry_run"] = False
                return current

        elif "Exit menu" in choice:
            if _confirm("Exit the menu without processing?", default=False):
                print("Exiting interactive mode. Run again with -I or provide -i/-o for CLI mode.")
                sys.exit(0)

    return current


# --------------------------------------------------------------------------------------
# Logging
# --------------------------------------------------------------------------------------

def setup_logging(verbose: bool, log_file: Optional[str] = None) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    fmt = "%(asctime)s | %(levelname)-8s | %(message)s"
    datefmt = "%H:%M:%S"

    handlers: List[logging.Handler] = [logging.StreamHandler(sys.stdout)]
    if log_file:
        handlers.append(logging.FileHandler(log_file, encoding="utf-8"))

    logging.basicConfig(level=level, format=fmt, datefmt=datefmt, handlers=handlers)
    logging.getLogger("pedalboard").setLevel(logging.WARNING)


# --------------------------------------------------------------------------------------
# Config handling
# --------------------------------------------------------------------------------------

def load_config(config_path: Optional[Path]) -> Dict[str, Any]:
    if not config_path:
        return {}
    p = Path(config_path).expanduser().resolve()
    if not p.exists():
        logging.warning(f"Config file not found: {p}")
        return {}
    try:
        with open(p, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        if isinstance(data, dict):
            logging.debug(f"Loaded config from {p}")
            for k in ("input_dir", "output_dir", "plugin_path", "log_file"):
                if k in data and data[k]:
                    data[k] = _sanitize_user_path(data[k])
            return data
        elif isinstance(data, str):
            # Support legacy single-line plugin_path only files
            logging.debug(f"Loaded legacy plugin-only config from {p}")
            return {"plugin_path": _sanitize_user_path(data)}
        else:
            return {}
    except Exception as e:
        logging.error(f"Failed to load config {p}: {e}")
        return {}


def resolve_value(cli_val: Any, config_val: Any, default: Any) -> Any:
    if cli_val is not None:
        return cli_val
    if config_val is not None:
        return config_val
    return default


# --------------------------------------------------------------------------------------
# Plugin discovery (very helpful on macOS)
# --------------------------------------------------------------------------------------

def find_lurssen_plugin(explicit_path: Optional[str]) -> Optional[Path]:
    """Locate the Lurssen .component bundle with smart defaults + globbing."""
    if explicit_path:
        cleaned = _sanitize_user_path(explicit_path)
        p = Path(cleaned or explicit_path).expanduser().resolve()
        if p.exists():
            return p
        logging.warning(f"Explicit plugin path does not exist: {p}")

    # Exact common names first
    candidates: List[Path] = [
        Path("/Library/Audio/Plug-Ins/Components/Lurssen Mastering Console.component"),
        Path("/Library/Audio/Plug-Ins/Components/Lurssen Mastering Console v6.component"),
        Path("/Library/Audio/Plug-Ins/Components/Lurssen Mastering EQ v6.component"),
        Path.home() / "Library/Audio/Plug-Ins/Components/Lurssen Mastering Console.component",
        Path.home() / "Library/Audio/Plug-Ins/Components/Lurssen Mastering EQ v6.component",
    ]

    for c in candidates:
        if c.exists():
            return c

    # Glob search in standard locations
    search_roots = [
        Path("/Library/Audio/Plug-Ins/Components"),
        Path.home() / "Library/Audio/Plug-Ins/Components",
        Path("/Library/Application Support/IK Multimedia"),
    ]

    for root in search_roots:
        if not root.exists():
            continue
        for match in root.rglob("*[Ll]urssen*.component"):
            if match.is_dir():
                return match

    # T-RackS specific deeper search
    tr_base = Path("/Library/Application Support/IK Multimedia")
    if tr_base.exists():
        for match in tr_base.glob("T-RackS*/Plug-Ins/Components/*[Ll]urssen*.component"):
            if match.is_dir():
                return match

    return None


def show_plugin_info(plugin_path: Path) -> None:
    """Load plugin and dump useful info for the user (parameter names are critical)."""
    print(f"\nLoading Lurssen plugin from:\n  {plugin_path}\n")
    try:
        plugin = pedalboard.load_plugin(str(plugin_path))
    except Exception as e:
        print(f"ERROR loading plugin: {e}")
        print("Check that the plugin is properly authorized and that T-RackS / Lurssen is activated.")
        sys.exit(1)

    print("Available parameters (name = current value):")
    try:
        params = dict(plugin.parameters)
        if not params:
            print("  (no exposed parameters — may be preset-driven only)")
        for name, value in sorted(params.items()):
            print(f"  {name}: {value}")
    except Exception as e:
        print(f"  Could not enumerate parameters: {e}")

    # Try to show preset info if the API exposes it
    if hasattr(plugin, "preset"):
        try:
            print(f"\nCurrent preset: {plugin.preset}")
        except Exception:
            pass

    # Some IK plugins expose programs/presets via other means
    print("\nTip: Use --preset \"Electronic\" (or \"EDM\", \"More Glue\", etc.)")
    print("     Common controls usually include: 'Input Drive', 'Push'")
    print("     Try running with --verbose to see what gets applied.\n")


# --------------------------------------------------------------------------------------
# Breakcore preset application (robust against exact param naming)
# --------------------------------------------------------------------------------------

def apply_breakcore_preset(plugin: Any, settings: Dict[str, Any], verbose: bool = False) -> None:
    """Apply breakcore-optimized settings to the Lurssen plugin instance."""
    param_names = list(plugin.parameters.keys())
    param_lower_map = {n.lower().strip(): n for n in param_names}

    applied: List[str] = []

    # 1. Preset / Style (if supported)
    preset = settings.get("preset")
    if preset:
        applied_preset = False
        if hasattr(plugin, "preset"):
            try:
                plugin.preset = preset
                applied.append(f"preset={preset}")
                applied_preset = True
            except Exception as ex:
                if verbose:
                    logging.debug(f"Could not set .preset: {ex}")

        if not applied_preset:
            for candidate in ("style", "preset", "program", "mode"):
                if candidate in param_lower_map:
                    key = param_lower_map[candidate]
                    try:
                        setattr(plugin, key, preset)
                        applied.append(f"{key}={preset}")
                        break
                    except Exception:
                        pass

    # 2. Input Drive (the big one for character and aggression)
    drive = settings.get("input_drive")
    if drive is not None:
        for cand in ("input drive", "drive", "inputdrive", "input gain", "input_gain", "drive amount"):
            if cand in param_lower_map:
                key = param_lower_map[cand]
                try:
                    setattr(plugin, key, float(drive))
                    applied.append(f"{key}={drive}")
                    break
                except Exception as ex:
                    if verbose:
                        logging.debug(f"Failed to set drive {key}: {ex}")

    # 3. Push (signature Lurssen control — adds energy/presence)
    push = settings.get("push")
    if push is not None:
        for cand in ("push", "push amount", "master push", "push level"):
            if cand in param_lower_map:
                key = param_lower_map[cand]
                try:
                    setattr(plugin, key, float(push))
                    applied.append(f"{key}={push}")
                    break
                except Exception as ex:
                    if verbose:
                        logging.debug(f"Failed to set push {key}: {ex}")

    # 4. Presence / high-mid boost (breakcore rhythmic clarity lives here ~3-4 kHz)
    presence = settings.get("presence")
    if presence is not None:
        applied_presence = False
        for cand in ("presence", "3.5 khz", "3 khz", "high mid", "mid presence", "eq presence",
                     "3500", "presence boost"):
            if cand in param_lower_map:
                key = param_lower_map[cand]
                try:
                    setattr(plugin, key, float(presence))
                    applied.append(f"{key}={presence}")
                    applied_presence = True
                    break
                except Exception:
                    pass

        # Special handling for Lurssen Mastering EQ v6 (very common on T-RackS installs)
        # Actual internal keys use snake_case: gain_3_lm, color, etc.
        if not applied_presence:
            for cand in ("gain_3_lm", "gain_3_rs", "gain_3", "gain3"):
                if cand in param_lower_map:
                    key = param_lower_map[cand]
                    try:
                        # Map our "presence" value (e.g. 3.8) directly into the -34..+34 dB range
                        setattr(plugin, key, float(presence))
                        applied.append(f"{key}={presence} (EQv6 presence)")
                        applied_presence = True
                        break
                    except Exception:
                        pass
            # Also try the 4th band (clarity ~6 kHz area) with a fraction of presence
            if not applied_presence:
                for cand in ("gain_4_lm", "gain_4_rs"):
                    if cand in param_lower_map:
                        key = param_lower_map[cand]
                        try:
                            setattr(plugin, key, round(float(presence) * 0.65, 2))
                            applied.append(f"{key}≈{round(float(presence)*0.65,1)} (EQv6 clarity)")
                            applied_presence = True
                            break
                        except Exception:
                            pass

        # Light color/saturation if available (helps aggression) — works on EQ v6
        # Lurssen Mastering EQ v6 exposes "color" in dB (~-15..+15), NOT a 0..1 normalized knob.
        for cand in ("color", "saturation", "drive"):
            if cand in param_lower_map:
                try:
                    drive_val = float(settings.get("input_drive", 4.8))
                    # Map typical drive ~3.5–6.5 → about +0.8..+5.5 dB of Color
                    val = max(-6.0, min(9.0, (drive_val - 3.0) * 1.6))
                    setattr(plugin, param_lower_map[cand], val)
                    applied.append(f"{param_lower_map[cand]}={val:.2f}dB (from input_drive)")
                    # Ensure Color section is enabled when the plugin has an on/off switch
                    if "color_on_off" in param_lower_map:
                        try:
                            setattr(plugin, param_lower_map["color_on_off"], True)
                            applied.append("color_on_off=On")
                        except Exception:
                            pass
                    break
                except Exception:
                    pass

    if verbose and applied:
        logging.info(f"Plugin parameters applied: {', '.join(applied)}")
    elif verbose:
        logging.info("No matching parameters found for breakcore preset — using plugin defaults/preset only.")

    if verbose:
        # Show what the plugin currently reports (great for debugging)
        try:
            current = {k: plugin.parameters[k] for k in param_names[:12]}
            logging.debug(f"Current param snapshot: {current}")
        except Exception:
            pass


# --------------------------------------------------------------------------------------
# Core processing — pedalboard + Lurssen (chunked, low memory)
# --------------------------------------------------------------------------------------

def _ensure_pcm_wav_for_pedalboard(input_path: Path) -> Tuple[Path, Optional[Path]]:
    """Return (path_to_read, temp_to_cleanup_or_None).

    For formats that pedalboard's AudioFile may not decode reliably (e.g. .mp3, .opus, some .m4a),
    we transcode once via ffmpeg to a temporary PCM WAV. Native formats (wav/aiff/flac)
    are returned as-is to avoid unnecessary work.
    """
    ext = input_path.suffix.lower()
    if ext in {".wav", ".wave", ".aiff", ".aif", ".flac"}:
        return input_path, None

    # mp3, m4a, opus, and any other compressed/container formats -> decode via ffmpeg
    temp_dir = Path(tempfile.gettempdir()) / "lurssen_mono_breakcore"
    temp_dir.mkdir(parents=True, exist_ok=True)
    unique = uuid.uuid4().hex[:8]
    temp_pcm = temp_dir / f"decode_{unique}_{input_path.stem}.wav"

    cmd: List[str] = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-i", str(input_path),
        "-vn",                     # drop any video streams
        "-acodec", "pcm_f32le",    # high quality float PCM for the plugin
        str(temp_pcm),
    ]
    subprocess.run(cmd, check=True, capture_output=True)
    return temp_pcm, temp_pcm


def process_with_lurssen(
    input_path: Path,
    plugin_path: Path,
    settings: Dict[str, Any],
    verbose: bool = False,
) -> Optional[Path]:
    """Process audio through Lurssen AU, collapse to true mono, write temp WAV. Returns temp path or None."""
    temp_dir = Path(tempfile.gettempdir()) / "lurssen_mono_breakcore"
    temp_dir.mkdir(parents=True, exist_ok=True)

    unique = uuid.uuid4().hex[:8]
    temp_wav = temp_dir / f"proc_{unique}_{input_path.stem}.wav"
    src_for_reading: Path = input_path
    src_temp_to_clean: Optional[Path] = None

    try:
        src_for_reading, src_temp_to_clean = _ensure_pcm_wav_for_pedalboard(input_path)

        plugin = pedalboard.load_plugin(str(plugin_path))
        apply_breakcore_preset(plugin, settings, verbose=verbose)

        with AudioFile(str(src_for_reading)) as reader:
            sr = int(reader.samplerate)
            # Use ~3 second chunks for good stateful plugin behavior + low RAM
            chunk_frames = max(4096, int(sr * 3.0))

            with AudioFile(str(temp_wav), "w", samplerate=sr, num_channels=1) as writer:
                while True:
                    audio = reader.read(chunk_frames)
                    if audio.shape[1] == 0:
                        break
                    processed = plugin(audio, sr)
                    if processed.shape[0] > 1:
                        # True mono collapse (average L+R). Critical for breakcore mono translation.
                        processed = np.mean(processed, axis=0, keepdims=True).astype(np.float32)
                    writer.write(processed)

        if not temp_wav.exists() or temp_wav.stat().st_size < 128:
            raise RuntimeError("Produced empty or tiny temp WAV")
        return temp_wav

    except Exception as e:
        logging.error(f"Plugin processing failed on {input_path.name}: {e}")
        if temp_wav.exists():
            try:
                temp_wav.unlink()
            except Exception:
                pass
        return None
    finally:
        # Clean up any temporary decoded source file we created for this file
        if src_temp_to_clean and src_temp_to_clean.exists():
            try:
                src_temp_to_clean.unlink()
            except Exception:
                pass


# --------------------------------------------------------------------------------------
# FFMPEG emulation (when user has no plugin or wants comparison)
# --------------------------------------------------------------------------------------

def build_ffmpeg_emulation_filter(drive: float, push: float, presence: float) -> str:
    """High-quality approximation of Lurssen character for aggressive electronic music."""
    # Blend push into presence (PUSH in Lurssen is broad enhancement)
    eff_presence = round(presence + (push * 0.55), 1)

    filters = [
        f"volume={drive}dB",                                    # Input drive / glue
        "equalizer=f=85:width_type=h:width=70:g=-2.8",          # Control muddy lows (mono friendly)
        "equalizer=f=210:width_type=h:width=85:g=0.8",          # Body weight
        f"equalizer=f=3250:width_type=h:width=820:g={eff_presence}",  # Core breakcore presence (3-4kHz)
        "equalizer=f=6800:width_type=h:width=1600:g=2.0",       # Clarity / cut
        "equalizer=f=10200:width_type=h:width=3800:g=1.0",      # Air
        "acompressor=threshold=-15.5dB:ratio=2.6:attack=5:release=65:makeup=1.6:knee=2.5",  # Controlled glue, keep dynamics
        "alimiter=limit=-1.3dB:level=0:attack=4:release=28",    # Soft ceiling, no brickwall kill
    ]
    return ",".join(filters)


def _append_codec_args(
    cmd: List[str],
    output_format: str,
    bitrate: str,
    wav_bit_depth: int,
) -> None:
    """Append ffmpeg codec/container args for the chosen final output format."""
    fmt = normalize_output_format(output_format)
    if fmt == "wav":
        cmd += [
            "-c:a", wav_pcm_codec(wav_bit_depth),
        ]
    else:
        cmd += [
            "-c:a", "aac",
            "-b:a", bitrate if str(bitrate).endswith("k") else f"{bitrate}k",
            "-movflags", "+faststart",
        ]


def process_with_ffmpeg_emulation(
    input_path: Path,
    output_path: Path,
    settings: Dict[str, Any],
    bitrate: str,
    loudness_target: Optional[float],
    true_peak: float,
    original_for_metadata: Optional[Path] = None,
    output_format: str = DEFAULT_OUTPUT_FORMAT,
    wav_bit_depth: int = DEFAULT_WAV_BIT_DEPTH,
) -> bool:
    """Single-pass ffmpeg decode + emulation filters + encode to final mono m4a or wav."""
    output_path.parent.mkdir(parents=True, exist_ok=True)

    drive = float(settings.get("input_drive", BREAKCORE_DEFAULTS["input_drive"]))
    push = float(settings.get("push", BREAKCORE_DEFAULTS["push"]))
    presence = float(settings.get("presence", BREAKCORE_DEFAULTS["presence"]))

    af_chain = build_ffmpeg_emulation_filter(drive, push, presence)

    # Peak / loudness control
    if loudness_target is not None:
        af_chain += f",loudnorm=I={loudness_target}:TP={true_peak}:LRA=9"
    else:
        af_chain += f",alimiter=limit={true_peak}dB:level=0:attack=4:release=30"

    cmd: List[str] = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-i", str(input_path),
    ]

    meta_src = original_for_metadata or input_path
    cmd += ["-i", str(meta_src), "-map", "0:a", "-map_metadata", "1"]

    cmd += [
        "-ar", "48000",
        "-ac", "1",
    ]
    _append_codec_args(cmd, output_format, bitrate, wav_bit_depth)
    cmd += [
        "-af", af_chain,
        str(output_path),
    ]

    try:
        subprocess.run(cmd, check=True, capture_output=True)
        return True
    except subprocess.CalledProcessError as e:
        err = e.stderr.decode(errors="ignore")[:400] if e.stderr else str(e)
        logging.error(f"ffmpeg emulation failed for {input_path.name}: {err}")
        return False


# --------------------------------------------------------------------------------------
# Final high-quality encode from processed WAV (plugin path)
# --------------------------------------------------------------------------------------

def encode_processed_wav(
    processed_wav: Path,
    original_path: Path,
    output_path: Path,
    bitrate: str,
    loudness_target: Optional[float],
    true_peak: float,
    output_format: str = DEFAULT_OUTPUT_FORMAT,
    wav_bit_depth: int = DEFAULT_WAV_BIT_DEPTH,
) -> bool:
    """Take the mono temp WAV from pedalboard and encode to final 48 kHz mono M4A or WAV.

    M4A uses AAC (+ optional loudnorm/alimiter). WAV uses PCM 16/24-bit with the same
    peak/loudness chain. Metadata is mapped from the original when ffmpeg can carry it.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)

    af_chain_parts: List[str] = []
    if loudness_target is not None:
        af_chain_parts.append(f"loudnorm=I={loudness_target}:TP={true_peak}:LRA=9")
    else:
        af_chain_parts.append(f"alimiter=limit={true_peak}dB:level=0:attack=5:release=40")

    cmd: List[str] = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-i", str(processed_wav),
        "-i", str(original_path),
        "-map", "0:a",
        "-map_metadata", "1",
        "-ar", "48000",
        "-ac", "1",
    ]
    _append_codec_args(cmd, output_format, bitrate, wav_bit_depth)
    if af_chain_parts:
        cmd += ["-af", ",".join(af_chain_parts)]
    cmd += [str(output_path)]

    try:
        subprocess.run(cmd, check=True, capture_output=True)
        return True
    except subprocess.CalledProcessError as e:
        err = e.stderr.decode(errors="ignore")[:400] if e.stderr else str(e)
        logging.error(f"ffmpeg encode failed for {original_path.name}: {err}")
        return False


def encode_processed_wav_to_m4a(
    processed_wav: Path,
    original_path: Path,
    output_path: Path,
    bitrate: str,
    loudness_target: Optional[float],
    true_peak: float,
) -> bool:
    """Backward-compatible wrapper — encode plugin temp WAV to mono M4A."""
    return encode_processed_wav(
        processed_wav,
        original_path,
        output_path,
        bitrate,
        loudness_target,
        true_peak,
        output_format="m4a",
    )


# --------------------------------------------------------------------------------------
# File discovery & path helpers
# --------------------------------------------------------------------------------------

def find_audio_files(root: Path) -> List[Path]:
    files: List[Path] = []
    for p in root.rglob("*"):
        if is_supported_audio_file(p):
            files.append(p)
    return sorted(files)


def compute_output_path(
    input_path: Path,
    input_root: Path,
    output_root: Path,
    suffix: str,
    output_format: str = DEFAULT_OUTPUT_FORMAT,
) -> Path:
    rel = input_path.relative_to(input_root)
    ext = output_extension(output_format)
    out_name = f"{input_path.stem}{suffix}{ext}"
    return output_root / rel.parent / out_name


# --------------------------------------------------------------------------------------
# Worker (must be top-level for multiprocessing spawn)
# --------------------------------------------------------------------------------------

def process_single_file(
    input_path_str: str,
    input_root_str: str,
    output_root_str: str,
    plugin_path_str: Optional[str],
    use_plugin: bool,
    settings: Dict[str, Any],
    bitrate: str,
    suffix: str,
    loudness_target: Optional[float],
    true_peak: float,
    overwrite: bool,
    dry_run: bool,
    verbose: bool,
    output_format: str = DEFAULT_OUTPUT_FORMAT,
    wav_bit_depth: int = DEFAULT_WAV_BIT_DEPTH,
) -> Dict[str, Any]:
    """Top-level worker function. Returns status dict. Safe for ProcessPoolExecutor."""
    input_path = Path(input_path_str)
    input_root = Path(input_root_str)
    output_root = Path(output_root_str)
    fmt = normalize_output_format(output_format)
    depth = normalize_wav_bit_depth(wav_bit_depth)

    output_path = compute_output_path(input_path, input_root, output_root, suffix, fmt)

    if output_path.exists() and not overwrite:
        return {"status": "skipped", "file": str(input_path), "reason": "exists"}

    if dry_run:
        return {"status": "dry-run", "file": str(input_path), "would_write": str(output_path)}

    temp_wav: Optional[Path] = None
    try:
        if use_plugin and plugin_path_str:
            plugin_path = Path(plugin_path_str)
            temp_wav = process_with_lurssen(input_path, plugin_path, settings, verbose=verbose)
            if temp_wav is None:
                return {"status": "error", "file": str(input_path), "error": "plugin processing failed"}

            ok = encode_processed_wav(
                temp_wav,
                input_path,
                output_path,
                bitrate,
                loudness_target,
                true_peak,
                output_format=fmt,
                wav_bit_depth=depth,
            )
            if ok:
                return {"status": "success", "file": str(input_path), "output": str(output_path)}
            return {
                "status": "error",
                "file": str(input_path),
                "error": f"ffmpeg encode of processed audio to {fmt} failed (see log)",
            }

        else:
            # Pure ffmpeg path (no temp intermediate needed)
            ok = process_with_ffmpeg_emulation(
                input_path,
                output_path,
                settings,
                bitrate,
                loudness_target,
                true_peak,
                original_for_metadata=input_path,
                output_format=fmt,
                wav_bit_depth=depth,
            )
            if ok:
                return {"status": "success", "file": str(input_path), "output": str(output_path)}
            return {
                "status": "error",
                "file": str(input_path),
                "error": "ffmpeg emulation encode failed (see log)",
            }

    except Exception as e:
        return {"status": "error", "file": str(input_path), "error": str(e)}
    finally:
        if temp_wav and temp_wav.exists():
            try:
                temp_wav.unlink()
            except Exception:
                pass


# --------------------------------------------------------------------------------------
# Main orchestration
# --------------------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        prog="lurssen-mono-breakcore",
        description=(
            "Batch process music discography to true mono 48 kHz M4A (AAC) or WAV using the Lurssen "
            "Mastering Console AU plugin (pedalboard) or high-quality ffmpeg emulation. "
            "Breakcore / aggressive electronic optimized."
        ),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    # Paths
    parser.add_argument("-c", "--config", type=Path, help="YAML config file (CLI overrides config)")
    parser.add_argument("-i", "--input-dir", type=Path, help="Root folder with album subfolders")
    parser.add_argument("-o", "--output-dir", type=Path, help="Output root (structure mirrored)")

    # Plugin
    parser.add_argument("-p", "--plugin-path", type=str, help="Path to Lurssen .component bundle")
    parser.add_argument("--no-plugin", action="store_true", help="Force ffmpeg-only emulation (no AU)")
    parser.add_argument("--show-plugin-params", action="store_true",
                        help="Load plugin, print parameters, and exit (great for exploring)")

    # Breakcore tuning
    parser.add_argument("--preset", help="Lurssen preset name (Electronic, EDM, etc.)")
    parser.add_argument("--input-drive", type=float, help="Input Drive amount (aggression/glue)")
    parser.add_argument("--push", type=float, help="Lurssen Push amount")
    parser.add_argument("--presence", type=float, help="Presence boost around 3-4 kHz")

    # Loudness philosophy
    # NOTE: defaults that can also live in config.yaml must be None here so resolve_value
    # can prefer the YAML value when the flag was not explicitly passed on the CLI.
    parser.add_argument("--loudness-target", type=float,
                        help="LUFS target (e.g. -14). DEFAULT=None (disabled). See README why -23 is bad for breakcore.")
    parser.add_argument("--true-peak", type=float, default=None,
                        help=f"True Peak ceiling in dBTP (default: {DEFAULT_TRUE_PEAK})")

    # Output
    parser.add_argument(
        "--format", "--output-format",
        dest="output_format",
        default=None,
        choices=list(SUPPORTED_OUTPUT_FORMATS),
        help=f"Output container/codec: m4a (AAC) or wav (PCM). Default: {DEFAULT_OUTPUT_FORMAT}",
    )
    parser.add_argument(
        "--wav-bit-depth",
        type=int,
        default=None,
        choices=list(SUPPORTED_WAV_BIT_DEPTHS),
        help=f"PCM bit depth when --format wav (default: {DEFAULT_WAV_BIT_DEPTH})",
    )
    parser.add_argument("--bitrate", default=None,
                        help=f"AAC bitrate when format is m4a, e.g. 256k or 320k (default: {DEFAULT_BITRATE})")
    parser.add_argument("--suffix", default=None,
                        help=f"Filename suffix before extension (default: {DEFAULT_SUFFIX})")
    parser.add_argument("--overwrite", action="store_true", default=None,
                        help="Overwrite existing outputs")

    # Performance & UX
    parser.add_argument("-j", "--jobs", type=int, default=None,
                        help="Parallel workers (1 is safest; default: 1)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be processed, do nothing")
    parser.add_argument("-v", "--verbose", action="store_true", default=None,
                        help="Debug logging + extra plugin info")
    parser.add_argument("--log-file", type=str, help="Optional log file path")
    parser.add_argument(
        "-I", "--interactive", "--menu",
        action="store_true",
        dest="interactive",
        help="Launch the intuitive interactive configuration menu (recommended for first use)",
    )

    args = parser.parse_args()

    # Sanitize any user-supplied paths (CLI often receives quoted strings when copy-pasted)
    if args.input_dir:
        args.input_dir = Path(_sanitize_user_path(str(args.input_dir)) or str(args.input_dir))
    if args.output_dir:
        args.output_dir = Path(_sanitize_user_path(str(args.output_dir)) or str(args.output_dir))
    if args.plugin_path:
        args.plugin_path = _sanitize_user_path(args.plugin_path)
    if args.config:
        # config path itself should also tolerate quotes
        args.config = Path(_sanitize_user_path(str(args.config)) or str(args.config))
    if args.log_file:
        args.log_file = _sanitize_user_path(args.log_file)

    # Handle --show-plugin-params very early (does not require input/output dirs)
    if args.show_plugin_params:
        cfg = load_config(args.config)
        plugin_path = find_lurssen_plugin(
            resolve_value(args.plugin_path, cfg.get("plugin_path"), None)
        )
        if not plugin_path:
            print("ERROR: Could not auto-detect Lurssen plugin. Use --plugin-path / -p")
            sys.exit(1)
        show_plugin_info(plugin_path)
        sys.exit(0)

    # --- Config merge ---
    cfg = load_config(args.config)

    # Selection may come from interactive mode and/or YAML config
    interactive_selection: Optional[Dict[str, Any]] = None

    # Launch intuitive menu if requested, or if required paths are missing (user-friendly default behavior)
    if getattr(args, "interactive", False) or (not args.input_dir and not cfg.get("input_dir")):
        # Merge any CLI hints that were already given into initial state
        initial = dict(cfg)
        if args.input_dir:
            initial["input_dir"] = _sanitize_user_path(str(args.input_dir))
        if args.output_dir:
            initial["output_dir"] = _sanitize_user_path(str(args.output_dir))
        if args.plugin_path:
            initial["plugin_path"] = _sanitize_user_path(args.plugin_path)
        if args.no_plugin:
            initial["use_plugin"] = False

        final_settings = run_interactive_mode(initial)

        # Feed interactive results back into args so the rest of main() (resolve + processing) works unchanged
        args.input_dir = Path(final_settings.get("input_dir")) if final_settings.get("input_dir") else None
        args.output_dir = Path(final_settings.get("output_dir")) if final_settings.get("output_dir") else None
        args.plugin_path = _sanitize_user_path(final_settings.get("plugin_path"))
        args.no_plugin = not final_settings.get("use_plugin", True)
        args.preset = final_settings.get("preset")
        args.input_drive = final_settings.get("input_drive")
        args.push = final_settings.get("push")
        args.presence = final_settings.get("presence")
        args.loudness_target = final_settings.get("loudness_target")
        args.true_peak = final_settings.get("true_peak")
        args.output_format = final_settings.get("output_format")
        args.wav_bit_depth = final_settings.get("wav_bit_depth")
        args.bitrate = final_settings.get("bitrate")
        args.suffix = final_settings.get("suffix")
        args.jobs = final_settings.get("jobs")
        args.overwrite = final_settings.get("overwrite")
        args.verbose = final_settings.get("verbose")
        if final_settings.get("_dry_run"):
            args.dry_run = True
        # Content selection from interactive menu (also accepted from YAML via cfg below)
        interactive_selection = {
            "selection_active": bool(final_settings.get("selection_active")),
            "selected_folders": list(final_settings.get("selected_folders") or []),
            "selected_files": list(final_settings.get("selected_files") or []),
        }
        # Re-merge cfg so resolve_value below prefers the fresh interactive values (treated as CLI)
        cfg = {}

    input_dir = resolve_value(args.input_dir, cfg.get("input_dir"), None)
    output_dir = resolve_value(args.output_dir, cfg.get("output_dir"), None)

    if not input_dir or not output_dir:
        parser.error("--input-dir and --output-dir (or config) are required")

    input_root = Path(_sanitize_user_path(str(input_dir)) or str(input_dir)).expanduser().resolve()
    output_root = Path(_sanitize_user_path(str(output_dir)) or str(output_dir)).expanduser().resolve()

    if not input_root.exists():
        # Helpful diagnostics for external volumes that are not mounted
        parts = input_root.parts
        volume_hint = ""
        if len(parts) >= 2 and parts[0] == "/" and parts[1] == "Volumes":
            vol = Path("/") / parts[1] / parts[2] if len(parts) >= 3 else None
            if vol is not None and not vol.exists():
                volume_hint = (
                    f"\n  The volume '{parts[2]}' is not mounted under /Volumes. "
                    f"Connect/mount the drive and try again."
                )
            elif vol is not None:
                volume_hint = f"\n  Volume is mounted at {vol}, but this subpath does not exist."
        parser.error(f"Input directory does not exist: {input_root}{volume_hint}")

    plugin_path = find_lurssen_plugin(
        resolve_value(args.plugin_path, cfg.get("plugin_path"), None)
    )

    use_plugin = not args.no_plugin and resolve_value(None, cfg.get("use_plugin"), True)

    # Settings (breakcore preset)
    settings: Dict[str, Any] = {
        "preset": resolve_value(args.preset, cfg.get("preset"), BREAKCORE_DEFAULTS["preset"]),
        "input_drive": resolve_value(args.input_drive, cfg.get("input_drive"), BREAKCORE_DEFAULTS["input_drive"]),
        "push": resolve_value(args.push, cfg.get("push"), BREAKCORE_DEFAULTS["push"]),
        "presence": resolve_value(args.presence, cfg.get("presence"), BREAKCORE_DEFAULTS["presence"]),
    }

    loudness_target = resolve_value(args.loudness_target, cfg.get("loudness_target"), None)
    true_peak = resolve_value(args.true_peak, cfg.get("true_peak"), DEFAULT_TRUE_PEAK)
    output_format = normalize_output_format(
        resolve_value(args.output_format, cfg.get("output_format"), DEFAULT_OUTPUT_FORMAT)
    )
    wav_bit_depth = normalize_wav_bit_depth(
        resolve_value(args.wav_bit_depth, cfg.get("wav_bit_depth"), DEFAULT_WAV_BIT_DEPTH)
    )
    bitrate = resolve_value(args.bitrate, cfg.get("bitrate"), DEFAULT_BITRATE)
    suffix = resolve_value(args.suffix, cfg.get("suffix"), DEFAULT_SUFFIX)
    jobs = max(1, int(resolve_value(args.jobs, cfg.get("jobs"), 1)))
    # store_true flags: only True means the user passed them; None/False → fall through to config
    overwrite = True if args.overwrite else bool(resolve_value(None, cfg.get("overwrite"), False))
    verbose = True if args.verbose else bool(resolve_value(None, cfg.get("verbose"), False))
    log_file = resolve_value(args.log_file, cfg.get("log_file"), None)

    setup_logging(verbose, log_file)

    # --- Early validation / guidance ---
    if use_plugin and not plugin_path:
        logging.warning(
            "No Lurssen plugin found and --no-plugin not set. "
            "Falling back to ffmpeg emulation. Use --plugin-path or install/locate the AU."
        )
        use_plugin = False

    if use_plugin:
        logging.info(f"Using Lurssen plugin: {plugin_path}")
    else:
        logging.info("Using ffmpeg-only emulation chain (no AU plugin)")

    if output_format == "wav":
        logging.info(f"Output format: WAV PCM {wav_bit_depth}-bit mono @ 48 kHz")
    else:
        logging.info(f"Output format: M4A AAC {bitrate} mono @ 48 kHz")

    # --- Discovery (respect folder/file selection from interactive menu or YAML) ---
    logging.info(f"Scanning {input_root} ...")
    selection_state: Dict[str, Any] = interactive_selection or {
        "selection_active": bool(cfg.get("selection_active")),
        "selected_folders": list(cfg.get("selected_folders") or []),
        "selected_files": list(cfg.get("selected_files") or []),
    }
    selected = resolve_selected_files(input_root, selection_state)
    if selected is None:
        files = find_audio_files(input_root)
        logging.info("No content selection filter — processing all supported audio under input dir.")
    else:
        files = selected
        logging.info(
            f"Content selection active: {len(selection_state.get('selected_folders') or [])} folder(s), "
            f"{len(selection_state.get('selected_files') or [])} file path(s) stored → "
            f"{len(files)} existing track(s) to process."
        )

    if not files:
        if selection_state.get("selection_active"):
            logging.error(
                "Selection is active but no matching audio files were found. "
                "Re-run the menu and use 'Select folders & files to convert'."
            )
        else:
            logging.error("No supported audio files found (.wav .aiff .flac .m4a .mp3 .opus)")
        sys.exit(1)

    logging.info(f"Queued {len(files)} track(s) for conversion.")

    if loudness_target is None:
        logging.info("Loudness normalization DISABLED (recommended for breakcore). Using light peak ceiling only.")
    else:
        logging.info(f"Loudness target: {loudness_target} LUFS (TP={true_peak} dBTP)")

    # --- Dry run early exit ---
    if args.dry_run:
        print("\nDRY RUN — would process:")
        for f in files[:12]:
            out = compute_output_path(f, input_root, output_root, suffix, output_format)
            print(f"  {f.relative_to(input_root)}  →  {out.relative_to(output_root) if output_root in out.parents else out}")
        if len(files) > 12:
            print(f"  ... and {len(files)-12} more")
        print(f"\nTotal: {len(files)} files  |  format: {output_format}"
              + (f" ({wav_bit_depth}-bit)" if output_format == "wav" else f" @ {bitrate}"))
        print("Run without --dry-run to execute.")
        return

    # --- Process ---
    output_root.mkdir(parents=True, exist_ok=True)

    worker_args_common = dict(
        input_root_str=str(input_root),
        output_root_str=str(output_root),
        plugin_path_str=str(plugin_path) if plugin_path else None,
        use_plugin=use_plugin,
        settings=settings,
        bitrate=bitrate,
        suffix=suffix,
        loudness_target=loudness_target,
        true_peak=true_peak,
        overwrite=overwrite,
        dry_run=False,
        verbose=verbose,
        output_format=output_format,
        wav_bit_depth=wav_bit_depth,
    )

    results: List[Dict[str, Any]] = []
    errors: List[Dict[str, Any]] = []
    successes: List[Dict[str, Any]] = []
    skipped: List[Dict[str, Any]] = []

    if jobs > 1:
        logging.info(f"Starting multiprocessing with {jobs} workers...")
        with ProcessPoolExecutor(max_workers=jobs) as executor:
            future_map = {}
            for f in files:
                fut = executor.submit(
                    process_single_file,
                    str(f),
                    **worker_args_common,
                )
                future_map[fut] = f

            for future in tqdm(as_completed(future_map), total=len(files), desc="Processing", unit="track"):
                try:
                    res = future.result()
                    results.append(res)
                except Exception as e:
                    f = future_map[future]
                    results.append({"status": "error", "file": str(f), "error": f"worker exception: {e}"})
    else:
        logging.info("Single-threaded processing (recommended for first runs)")
        for f in tqdm(files, desc="Processing", unit="track"):
            res = process_single_file(str(f), **worker_args_common)
            results.append(res)

    # --- Summary ---
    for r in results:
        st = r.get("status")
        if st == "success":
            successes.append(r)
        elif st == "error":
            errors.append(r)
        elif st == "skipped":
            skipped.append(r)

    print("\n" + "=" * 60)
    print(f"COMPLETE  |  Success: {len(successes)}   Errors: {len(errors)}   Skipped: {len(skipped)}")
    print("=" * 60)

    if errors:
        print("\nFAILED FILES:")
        for e in errors:
            print(f"  • {Path(e['file']).name}")
            if "error" in e:
                print(f"    └─ {e['error']}")

    if successes:
        print(f"\nOutputs written under: {output_root}")
        print(f"Example: {successes[0].get('output')}")

    if errors:
        sys.exit(2)
    elif not successes and not skipped:
        sys.exit(1)


if __name__ == "__main__":
    main()
