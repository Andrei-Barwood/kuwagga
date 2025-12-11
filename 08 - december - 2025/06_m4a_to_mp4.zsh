#!/bin/zsh

# How To Use This Script

# Run the script normally.

# When ranger launches:
# Navigate with arrow keys or type to jump.
# Go into your external drive folder.
# To choose the folder, press: Shift-G (uppercase G) then Enter (this sets the present folder).
# Quit ranger by pressing q.
# The script will now use the folder you picked.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

QUALITY_MODE="vbr"   # "vbr" or "cbr"
VBR_QUALITY=0        # VBR quality (0=highest)
CBR_BITRATE="320k"   # CBR bitrate

echo "${GREEN}=== Audio Conversion Menu ===${NC}"

# Check dependencies
for prog in ffmpeg ranger; do
    if ! command -v $prog &> /dev/null; then
        echo "${RED}Error: $prog is not installed.${NC}"
        exit 1
    fi
done

# Select conversion type
echo "${YELLOW}Choose conversion type:${NC}"
echo "  1) M4A to MP4 (YouTube video)"
echo "  2) WAV to M4A (high quality)"
echo "  q) Quit"
read -k1 mode
echo ""
if [[ "$mode" == "q" ]]; then
    echo "${YELLOW}Goodbye!${NC}"
    exit 0
fi

if [[ "$mode" != "1" && "$mode" != "2" ]]; then
    echo "${RED}Invalid selection.${NC}"
    exit 1
fi

# Select folder with ranger
TMP_FILE="/tmp/choosedir_$$"
echo "${YELLOW}Navigate to the desired folder in ranger; when ready, Shift-G then Enter, then quit ranger with q.${NC}"
ranger --choosedir="$TMP_FILE" "$HOME"
SOURCE_DIR=$(cat "$TMP_FILE")
rm -f "$TMP_FILE"

if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]]; then
    echo "${RED}No valid folder selected. Exiting.${NC}"
    exit 1
fi
echo "${GREEN}Selected folder: $SOURCE_DIR${NC}"
cd "$SOURCE_DIR" || {
    echo "${RED}Error: Cannot enter $SOURCE_DIR${NC}"
    exit 1
}

# Ask for output directory name
if [[ "$mode" == "1" ]]; then
    echo "${YELLOW}Enter name for the MP4 output directory (Enter for default: converted_videos):${NC}"
else
    echo "${YELLOW}Enter name for the M4A output directory (Enter for default: converted):${NC}"
fi
read -r output_dirname
[[ -z "$output_dirname" ]] && output_dirname=$([[ "$mode" == "1" ]] && echo "converted_videos" || echo "converted")
mkdir -p "$output_dirname"

if [[ "$mode" == "1" ]]; then
    m4a_files=(*.m4a(N))
    if [[ ${#m4a_files[@]} -eq 0 ]]; then
        echo "${RED}No .m4a files found in this folder.${NC}"
        exit 1
    fi
    
    echo "${YELLOW}Found M4A files:${NC}"
    for f in "${m4a_files[@]}"; do echo "  - $f"; done

    # Check for cover.png
    if [[ ! -f "cover.png" ]]; then
        echo "${RED}Error: No cover.png found in: $SOURCE_DIR${NC}"
        exit 1
    fi

    echo -n "${YELLOW}Convert ALL these to MP4? (y/n): ${NC}"
    read response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "${YELLOW}Conversion cancelled.${NC}"
        exit 0
    fi

    success_count=0
    fail_count=0

for audio_file in "${m4a_files[@]}"; do
    filename="${audio_file:r}"
    output_file="${output_dirname}/${filename}.mp4"
    # Get the audio duration in seconds
    duration=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$audio_file")
    audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$audio_file")
    # If duration is empty, skip this file
    if [[ -z "$duration" ]]; then
        echo "${RED}Couldn't determine duration for: $audio_file, skipping.${NC}"
        ((fail_count++))
        continue
    fi
    echo "${YELLOW}Converting: $audio_file (duration: $duration seconds)${NC}"
    audio_args=()
    if [[ "$audio_codec" == "aac" ]]; then
        # Avoid re-encoding to prevent padding/timestamp weirdness.
        audio_args=(-c:a copy)
    else
        audio_args=(-c:a aac -b:a 192k -ar 48000)
    fi

    ffmpeg -hide_banner -loglevel error \
        -loop 1 -framerate 30 -i "cover.png" -i "$audio_file" \
        -map 0:v:0 -map 1:a:0 \
        -t "$duration" -shortest \
        -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
        "${audio_args[@]}" \
        -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" \
        -movflags +faststart \
        -y "$output_file"
    if [[ $? -eq 0 ]]; then
        echo "${GREEN}✓ Successfully converted: $output_file${NC}"
        out_duration=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$output_file")
        if [[ -n "$out_duration" ]]; then
            echo "${GREEN}  Duration check: input=${duration}s, output=${out_duration}s${NC}"
        fi
        ((success_count++))
    else
        echo "${RED}✗ Failed to convert: $audio_file${NC}"
        ((fail_count++))
    fi
done


    echo "\n${GREEN}=== MP4 Conversion Complete ===${NC}"
    echo "Successfully converted: $success_count file(s)"
    [[ $fail_count -gt 0 ]] && echo "${RED}Failed: $fail_count file(s)${NC}"
    echo "Output directory: ${output_dirname}/"
else
    wav_files=(*.wav(N))
    if [[ ${#wav_files[@]} -eq 0 ]]; then
        echo "${RED}No WAV files found in this folder.${NC}"
        exit 1
    fi
    
    echo "${YELLOW}Found WAV files:${NC}"
    for f in "${wav_files[@]}"; do echo "  - $f"; done
    
    echo "Quality mode: $QUALITY_MODE"
    [[ "$QUALITY_MODE" == "vbr" ]] && echo "VBR Quality: $VBR_QUALITY" || echo "Bitrate: $CBR_BITRATE"
    
    echo -n "${YELLOW}Convert ALL these to M4A? (y/n): ${NC}"
    read response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "${YELLOW}Conversion cancelled.${NC}"
        exit 0
    fi

    success_count=0
    fail_count=0
    for file in "${wav_files[@]}"; do
        filename=$(basename "$file")
        basename="${filename%.*}"
        output_file="${output_dirname}/${basename}.m4a"
        echo "${YELLOW}Converting: $filename${NC}"
        if [[ "$QUALITY_MODE" == "vbr" ]]; then
            ffmpeg -i "$file" \
                -c:a aac -q:a $VBR_QUALITY -ar 48000 "$output_file" \
                -y -hide_banner -loglevel error
        else
            ffmpeg -i "$file" \
                -c:a aac -b:a $CBR_BITRATE -ar 48000 "$output_file" \
                -y -hide_banner -loglevel error
        fi
        if [[ $? -eq 0 ]]; then
            echo "${GREEN}✓ Successfully converted: $filename${NC}"
            ((success_count++))
        else
            echo "${RED}✗ Failed to convert: $filename${NC}"
            ((fail_count++))
        fi
    done

    echo "\n${GREEN}=== M4A Conversion Complete ===${NC}"
    echo "Successfully converted: $success_count file(s)"
    [[ $fail_count -gt 0 ]] && echo "${RED}Failed: $fail_count file(s)${NC}"
    echo "Output directory: ${output_dirname}/"
fi
