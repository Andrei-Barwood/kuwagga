#!/bin/zsh

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="${0:a:h}"
cd "$SCRIPT_DIR"

echo "${GREEN}=== M4A to MP4 Video Converter for YouTube ===${NC}\n"

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "${RED}Error: ffmpeg is not installed. Please install it first.${NC}"
    echo "Install via: brew install ffmpeg (Mac) or apt-get install ffmpeg (Linux)"
    exit 1
fi

# Find all .m4a files in the current directory
m4a_files=(*.m4a(N))

# Check if any m4a files exist
if [[ ${#m4a_files[@]} -eq 0 ]]; then
    echo "${RED}No .m4a files found in the current directory.${NC}"
    exit 1
fi

# List all m4a files
echo "${YELLOW}Found ${#m4a_files[@]} M4A file(s):${NC}"
for file in "${m4a_files[@]}"; do
    echo "  - $file"
done
echo ""

# Ask user if they want to convert all files
echo -n "Do you want to convert all ${#m4a_files[@]} files? (y/n): "
read response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "${YELLOW}Conversion cancelled.${NC}"
    exit 0
fi

# Look for cover.png in subdirectories
cover_image=""
for dir in */; do
    if [[ -f "${dir}cover.png" ]]; then
        cover_image="${dir}cover.png"
        echo "${GREEN}Found cover image: $cover_image${NC}\n"
        break
    fi
done

# If no cover.png found in subdirectories, check current directory
if [[ -z "$cover_image" ]] && [[ -f "cover.png" ]]; then
    cover_image="cover.png"
    echo "${GREEN}Found cover image in current directory: $cover_image${NC}\n"
fi

# Exit if no cover image found
if [[ -z "$cover_image" ]]; then
    echo "${RED}Error: No cover.png found in any subdirectory or current directory.${NC}"
    exit 1
fi

# Create output directory if it doesn't exist
output_dir="converted_videos"
mkdir -p "$output_dir"

# Convert each m4a file
success_count=0
fail_count=0

for audio_file in "${m4a_files[@]}"; do
    # Get filename without extension
    filename="${audio_file:r}"
    output_file="${output_dir}/${filename}.mp4"
    
    echo "${YELLOW}Converting: $audio_file${NC}"
    
    # FFmpeg command optimized for YouTube upload
    # - loop 1: loop the image infinitely
    # - libx264: H.264 codec (YouTube recommended)
    # - preset slow: better compression
    # - crf 18: high quality (lower is better, 18-23 is good)
    # - pix_fmt yuv420p: ensures compatibility with all devices
    # - c:a aac: AAC audio codec (YouTube recommended)
    # - b:a 192k: audio bitrate 192kbps
    # - ar 48000: audio sample rate 48kHz
    # - shortest: finish when audio ends
    # - vf scale: ensure even dimensions and 1080p resolution
    
    ffmpeg -loop 1 -framerate 1 -i "$cover_image" -i "$audio_file" \
        -c:v libx264 -preset slow -crf 18 \
        -c:a aac -b:a 192k -ar 48000 \
        -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p" \
        -movflags +faststart \
        -shortest \
        -y "$output_file" 2>&1 | grep -E "time=|error|Error"
    
    if [[ $? -eq 0 ]]; then
        echo "${GREEN}✓ Successfully converted: $output_file${NC}\n"
        ((success_count++))
    else
        echo "${RED}✗ Failed to convert: $audio_file${NC}\n"
        ((fail_count++))
    fi
done

# Summary
echo "\n${GREEN}=== Conversion Complete ===${NC}"
echo "Successfully converted: ${success_count} file(s)"
if [[ $fail_count -gt 0 ]]; then
    echo "${RED}Failed: ${fail_count} file(s)${NC}"
fi
echo "Output directory: ${output_dir}/"

