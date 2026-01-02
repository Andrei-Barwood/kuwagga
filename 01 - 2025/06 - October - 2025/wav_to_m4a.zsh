#!/bin/zsh

# WAV to M4A High-Quality Converter
# Converts WAV files to M4A using AAC codec at maximum quality

# Configuration - Adjust these settings as needed
QUALITY_MODE="vbr"  # Options: "vbr" or "cbr"
VBR_QUALITY=0       # VBR: 0 (highest) to 2 (very high quality)
CBR_BITRATE="320k"  # CBR: Use if you prefer constant bitrate (256k-320k recommended)
OUTPUT_DIR="./converted"  # Output directory for converted files

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "${RED}Error: ffmpeg is not installed${NC}"
    echo "Install with: brew install ffmpeg"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to convert a single file
convert_file() {
    local input_file="$1"
    local filename=$(basename "$input_file")
    local basename="${filename%.*}"
    local output_file="$OUTPUT_DIR/${basename}.m4a"
    
    echo "${YELLOW}Converting: $filename${NC}"
    
    if [[ "$QUALITY_MODE" == "vbr" ]]; then
        # VBR mode - highest quality (q:a 0 is best)
        ffmpeg -i "$input_file" \
            -c:a aac \
            -q:a $VBR_QUALITY \
            -ar 48000 \
            "$output_file" \
            -y -hide_banner -loglevel error
    else
        # CBR mode - constant bitrate
        ffmpeg -i "$input_file" \
            -c:a aac \
            -b:a $CBR_BITRATE \
            -ar 48000 \
            "$output_file" \
            -y -hide_banner -loglevel error
    fi
    
    if [[ $? -eq 0 ]]; then
        echo "${GREEN}✓ Successfully converted: $filename${NC}"
    else
        echo "${RED}✗ Failed to convert: $filename${NC}"
    fi
}

# Main conversion logic
echo "Starting WAV to M4A conversion..."
echo "Quality mode: $QUALITY_MODE"
[[ "$QUALITY_MODE" == "vbr" ]] && echo "VBR Quality: $VBR_QUALITY" || echo "Bitrate: $CBR_BITRATE"
echo "Output directory: $OUTPUT_DIR"
echo "---"

# Process files based on arguments
if [[ $# -eq 0 ]]; then
    # No arguments - convert all WAV files in current directory
    wav_files=(*.wav(N))
    if [[ ${#wav_files[@]} -eq 0 ]]; then
        echo "${RED}No WAV files found in current directory${NC}"
        exit 1
    fi
    
    for file in "${wav_files[@]}"; do
        convert_file "$file"
    done
else
    # Convert specified files or directories
    for arg in "$@"; do
        if [[ -f "$arg" && "$arg" == *.wav ]]; then
            convert_file "$arg"
        elif [[ -d "$arg" ]]; then
            # Process directory
            for file in "$arg"/**/*.wav(N); do
                convert_file "$file"
            done
        else
            echo "${RED}Skipping: $arg (not a WAV file or directory)${NC}"
        fi
    done
fi

echo "---"
echo "${GREEN}Conversion complete!${NC}"
