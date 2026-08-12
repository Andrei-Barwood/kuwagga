# lurssen-mono-breakcore

**Batch process entire music discographies to true mono 48 kHz M4A or WAV using the Lurssen Mastering Console style — optimized for breakcore and aggressive electronic music.**

Run with no arguments (or `-I`) for an **interactive menu** that lists all the configurations and suggested ready-to-use profiles so you don't have to remember flags.

- Primary engine: **IK Multimedia Lurssen Mastering Console** (or Lurssen Mastering EQ) Audio Unit via `pedalboard.load_plugin()` — exact sound you love.
- High-quality fallback: carefully tuned `ffmpeg` filter chain that emulates Lurssen character (drive, glue, presence, controlled dynamics).
- Output formats (always mono @ 48 kHz):
  - **M4A / AAC** (256–320 kbps) — listening, distribution, portable libraries
  - **WAV / PCM** (16- or 24-bit) — DAW work, further production, archival masters
- Folder structure preserved. Clear naming. Robust error handling. Optional multiprocessing.

## Why mono for breakcore?

Breakcore is chaotic, rhythmic, and often extremely wide. Collapsing to true mono forces the important elements (kicks, snares, leads, bass stabs) to translate on every system — club rigs, phones, laptop speakers, car stereos.

Lurssen Mastering Console is loved because it delivers **glue + aggression + musicality** with very few controls. This tool applies a breakcore-friendly starting point and then forces a clean mono downmix at the end.

## Key Philosophy (Breakcore-specific)

- **Transient punch and rhythmic clarity first.** Do not smash the life out of it.
- **Keep some dynamic range.** Breakcore energy lives in the contrast between brutal kicks and chaotic breaks.
- **Presence around 3–4.5 kHz** helps snares, hi-hats and distorted leads cut in mono.
- **Moderate Input Drive + noticeable Push** for glue without turning everything into a wall.
- **NO strict EBU R128 normalization by default.** -23 LUFS is for broadcast/TV. It makes music quiet and usually requires heavy limiting that kills the chaotic beauty of breakcore.
  - Use `-14`, `-12`, `-10`, or `-8` LUFS only when you have a specific reason (streaming loudness normalization war, video platform, etc.).
  - The tool applies a gentle true-peak ceiling (`-1.0 dBTP` by default) instead.

## Requirements

- **macOS** (Audio Units are macOS-specific)
- Python 3.9+
- **ffmpeg** (for final encoding + emulation fallback)
- **pedalboard** + numpy + pyyaml + tqdm (see `requirements.txt`)
- IK Multimedia **T-RackS** (or standalone Lurssen Mastering Console) installed so the AU is present and authorized.

## Installation

```bash
# 1. Clone or download this folder
cd /path/to/this/project

# 2. Create venv (recommended)
python3 -m venv .venv
source .venv/bin/activate

# 3. Install Python deps
pip install -r requirements.txt

# 4. Install ffmpeg
brew install ffmpeg

# 5. (Optional but recommended) Make the script directly executable
chmod +x lurssen_mono_breakcore.py
```

## Finding Your Lurssen Plugin Path

This is the most common setup hurdle.

Run these commands and look for anything containing "Lurssen":

```bash
# List all Audio Units
auval -a | grep -i lur

# Alternative (more modern)
pluginkit -m -v | grep -i lurssen

# Find the actual .component bundles
find /Library/Audio/Plug-Ins/Components -name "*Lurssen*" -type d 2>/dev/null
find ~/Library/Audio/Plug-Ins/Components -name "*Lurssen*" -type d 2>/dev/null

# T-RackS location
find "/Library/Application Support/IK Multimedia" -name "*Lurssen*" -type d 2>/dev/null
```

Typical paths you will see:

- `/Library/Audio/Plug-Ins/Components/Lurssen Mastering Console.component`
- `/Library/Audio/Plug-Ins/Components/Lurssen Mastering EQ v6.component`
- `/Library/Application Support/IK Multimedia/T-RackS 6/Plug-Ins/Components/Lurssen Mastering EQ v6.component`

**Note:** If you only see "Lurssen Mastering EQ v6", that is still very usable (it's the standout EQ module extracted from the Console workflow). The full Console has the classic "Input Drive + Push + 5-band" experience.

Pass the exact path with `--plugin-path` or put it in `config.yaml`.

You can also use the built-in inspector:

```bash
python lurssen_mono_breakcore.py --plugin-path "/Library/.../Lurssen Mastering Console.component" --show-plugin-params
```

This will print every parameter the plugin exposes. Extremely useful for fine-tuning.

## Quick Start

### Recommended: Interactive Menu (easiest)

Just run the script. If you don't provide input/output paths it automatically launches an **intuitive menu**:

```bash
python lurssen_mono_breakcore.py
# or explicitly
python lurssen_mono_breakcore.py -I
```

The menu shows a live summary of **every configuration** and offers:

- **Suggested Mastering Profiles** — pick from "Balanced Breakcore (recommended)", "Aggressive Breakcore", "Heavy Glue & Push", "Clarity & Air", "Emulation Only", or "Custom values...". These encode the previously manual drive/push/presence/preset combinations.
- **Select folders & files to convert** — multi-select menu of folders and subfolders (up to **4 levels** under the input root), then optionally pick individual tracks inside those folders. Clear the selection anytime to process the whole tree again.
- Guided prompts for paths, plugin, loudness, jobs, etc.
- One-key actions: load/save YAML, preview files, inspect the AU parameters, start processing.

This replaces having to remember or look up all the CLI flags / YAML keys. Selection is stored as relative paths (`selected_folders` / `selected_files` / `selection_active`) and can be saved/loaded with `config.yaml`.

### 1. Using a config file

```bash
cp config.example.yaml config.yaml
# edit paths in config.yaml
python lurssen_mono_breakcore.py -c config.yaml
```

### 2. Pure CLI (no config)

```bash
python lurssen_mono_breakcore.py \
  -i ~/Music/MyBreakcoreDiscography \
  -o ~/Music/MyBreakcoreDiscography_MONO \
  --plugin-path "/Library/Audio/Plug-Ins/Components/Lurssen Mastering Console.component" \
  --preset "Electronic" \
  --input-drive 5.2 \
  --push 3.5 \
  -j 2
```

## CLI Reference (most useful flags)

| Flag                    | Description                                      | Default          |
|-------------------------|--------------------------------------------------|------------------|
| `-i`, `--input-dir`     | Root containing album folders                    | (required)       |
| `-o`, `--output-dir`    | Where mirrored mono structure will be written    | (required)       |
| `-c`, `--config`        | YAML config (CLI wins)                           | -                |
| `-p`, `--plugin-path`   | Explicit .component path                         | auto-detect      |
| `--no-plugin`           | Force ffmpeg emulation only                      | false            |
| `--preset`              | Lurssen style preset name                        | Electronic       |
| `--input-drive`         | Drive amount (0–12 range typical)                | 4.8              |
| `--push`                | Push amount                                      | 3.2              |
| `--presence`            | Extra 3–4 kHz emphasis                           | 3.5              |
| `--loudness-target`     | LUFS (e.g. -14). `null`/omitted = disabled       | disabled         |
| `--true-peak`           | dBTP ceiling                                     | -1.0             |
| `--format`              | Output format: `m4a` or `wav`                    | m4a              |
| `--wav-bit-depth`       | PCM depth when format is `wav` (`16` / `24`)     | 24               |
| `--bitrate`             | AAC bitrate when format is `m4a` (`256k` / `320k`) | 320k           |
| `--suffix`              | Appended to filename before extension            | _MONO_LURSSEN_BREAKCORE |
| `-j`, `--jobs`          | Parallel workers (M1/M2/M3 love 2–4)             | 1                |
| `--overwrite`           | Overwrite existing outputs                       | false            |
| `--dry-run`             | List what would happen, do nothing               | false            |
| `-v`, `--verbose`       | Debug logs + applied parameter names             | false            |
| `--show-plugin-params`  | Load plugin and dump parameters, then exit       | -                |
| `-I`, `--interactive`   | Launch the guided menu with suggested profiles (all config options in one place) | auto (when no paths) |

## Output Structure

Input:
```
Discography/
  2023 - Chaos Engine/
    01 - Neurotic Break.flac
    02 - 9k Amens.wav
  2024 - Distorted Serenity/
    ...
```

Output (default M4A):
```
Discography_MONO/
  2023 - Chaos Engine/
    01 - Neurotic Break_MONO_LURSSEN_BREAKCORE.m4a
    02 - 9k Amens_MONO_LURSSEN_BREAKCORE.m4a
  ...
```

With `--format wav` (or `output_format: wav` in YAML), the same structure uses `.wav` files instead (PCM 24-bit by default).

## Development Notes

For future development sessions, detailed implementation notes, debugging information, architecture decisions, and "how to extend" guides are kept in **`BITACORA.md`**.

As of 2026-07-08 the tool is in a **fully working, production-ready state**.

## Recommended Breakcore Settings (starting point)

```yaml
preset: "Electronic"     # or "EDM" / "More Glue" if available
input_drive: 4.5 - 5.5
push: 2.8 - 4.0
presence: 3.0 - 4.5
loudness_target: null
true_peak: -1.0
```

In the interactive menu you can instantly apply full named profiles that bake in good combinations:

- **Balanced Breakcore (recommended)**
- **Aggressive Breakcore**
- **Heavy Glue & Push**
- **Clarity & Air (lighter)**
- **Emulation Only (ffmpeg)**

Listen on multiple systems (especially bad ones) after the first few albums.

Slightly lower drive + higher push often gives more "air" and rhythmic snap.

Higher drive gives more analog-style glue and saturation.

## Output format: M4A vs WAV

| Format | When to use | Notes |
|--------|-------------|--------|
| `m4a` (default) | Everyday listening library, phones, streaming prep | AAC 256k/320k, small files |
| `wav` | Renoise / DAW import, further processing, archival masters | PCM 16- or 24-bit (24 recommended) |

CLI examples:

```bash
# WAV 24-bit mono @ 48 kHz (recommended for production)
python lurssen_mono_breakcore.py -c config.yaml --format wav

# WAV 16-bit (smaller, CD-like integer depth)
python lurssen_mono_breakcore.py -c config.yaml --format wav --wav-bit-depth 16

# Explicit M4A (default)
python lurssen_mono_breakcore.py -c config.yaml --format m4a --bitrate 320k
```

In the interactive menu: **Output settings → Output format → m4a | wav**.

## Metadata

The tool attempts to copy metadata (title, artist, album, track number, etc.) from the original file into the final output using ffmpeg's `-map_metadata`. This works best for M4A destinations when the source is FLAC or M4A. WAV carries little embedded metadata either as source or destination.
## Multiprocessing Notes

- Default is `--jobs 1` (safest).
- On Apple Silicon, 2–4 workers often gives excellent throughput because each worker loads its own plugin instance.
- Some Audio Units can be finicky with heavy concurrency. If you see crashes or "not authorized" errors, drop back to 1 or 2 jobs.
- Each worker is independent — errors in one file do not stop the rest.

## Error Handling & Robustness

- Corrupted or unreadable files are logged and skipped.
- Partial writes are cleaned up.
- Full summary at the end with list of failures.
- Dry-run mode to validate your folder structure before committing CPU time.

## FFmpeg Emulation Chain Details

When `--no-plugin` or no AU is found, the tool builds this approximate chain (stereo processing then mono collapse):

1. Input Drive (volume)
2. Low-end cleanup (mono-safe)
3. Body + low-mid weight
4. **Key presence boost ~3.25 kHz** (the breakcore magic zone)
5. Clarity / cut around 6–7 kHz
6. Gentle air
7. Moderate compression (glue, ratio ~2.6:1, not brickwall)
8. Soft true-peak ceiling

It is surprisingly good, but **the real Lurssen AU is the goal**.

## Full Example Commands

See the end of this README for ready-to-run examples.

## Troubleshooting

**"No Lurssen plugin found"**
- Run the discovery commands above.
- Make sure T-RackS / Lurssen is authorized (open the standalone app once).
- Try both system and user `~/Library` locations.

**Plugin loads but parameters do nothing**
- Use `--show-plugin-params` and `--verbose` to see what names actually exist.
- The tool does fuzzy matching on common names ("input drive", "push", "presence").
- Some versions expose different names — edit `apply_breakcore_preset` if needed.

**Crackles or dropouts**
- Reduce `--jobs` to 1.
- Make sure you're not running out of RAM on huge files (chunked processing helps).

**Metadata missing**
- Normal for WAV sources. Consider tagging the M4As afterwards with MusicBrainz Picard or similar.

**Want even more aggression**
- Raise `--input-drive` to 6–7.
- Combine with the internal "More Glue" or "Electronic" preset.

## Extending the Tool

The code is intentionally readable and "vibe-coding" friendly:

- `apply_breakcore_preset()` — add more param matching here.
- `build_ffmpeg_emulation_filter()` — tweak the fallback sound.
- `process_single_file()` worker is isolated.
- Everything is typed where it matters.

PRs / forks for additional genre curves (IDM, jungle, speedcore, etc.) are welcome.

## License

MIT. Use it on your own discography guilt-free.

---

## Example Commands (copy-paste ready)

```bash
# 1. Basic run with auto-detected plugin (or config)
python lurssen_mono_breakcore.py \
  -i ~/Music/Breakcore_Archive \
  -o ~/Music/Breakcore_Archive_MONO \
  -j 2

# 1b. Same but export 24-bit mono WAV (for Renoise / DAW)
python lurssen_mono_breakcore.py \
  -i ~/Music/Breakcore_Archive \
  -o ~/Music/Breakcore_Archive_MONO_WAV \
  --format wav \
  --wav-bit-depth 24 \
  -j 2

# 2. Explicit plugin + more aggressive breakcore settings + verbose
python lurssen_mono_breakcore.py \
  -i ~/Music/Discography \
  -o ~/Music/Discography_LURSSEN_MONO \
  --plugin-path "/Library/Audio/Plug-Ins/Components/Lurssen Mastering Console.component" \
  --preset "Electronic" \
  --input-drive 5.5 \
  --push 3.8 \
  --presence 4.0 \
  --true-peak -0.8 \
  -j 3 \
  -v

# 3. Dry run to verify structure, then ffmpeg-only comparison pass
python lurssen_mono_breakcore.py \
  -i ~/Music/TestFolder \
  -o ~/Music/TestFolder_EMU \
  --no-plugin \
  --dry-run

# Real ffmpeg-only run (great for A/B against the plugin)
python lurssen_mono_breakcore.py \
  -i ~/Music/TestFolder \
  -o ~/Music/TestFolder_EMU \
  --no-plugin \
  --bitrate 256k
```

After the first album finishes, listen in mono on a phone speaker and a club system (or good headphones with mono switch). Tweak drive/push/presence and re-process that album until it slaps.

Enjoy the glue.
