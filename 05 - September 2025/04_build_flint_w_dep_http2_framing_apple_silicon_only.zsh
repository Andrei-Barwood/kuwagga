#!/bin/zsh

# FLINT Apple Silicon Framework Builder with Static Dependencies
# Builds FLINT 3.3.1 with GMP 6.3.0 and MPFR 4.2.2 statically linked for Apple Silicon (arm64) only

set -e

# Configuration - Latest versions as of September 2025
FLINT_VERSION="3.3.1"
GMP_VERSION="6.3.0" 
MPFR_VERSION="4.2.2"

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
INSTALL_DIR="$BUILD_DIR/install"
FRAMEWORK_DIR="$BUILD_DIR/frameworks"

# Apple Silicon (arm64) only
ARCH="arm64"
ARCH_DIR="$BUILD_DIR/macOS-${ARCH}"
BUILD_ARCH_DIR="$BUILD_DIR/build-macOS-${ARCH}"

# Alternative download URLs to avoid HTTP2 issues
GMP_URL="https://ftp.gnu.org/gnu/gmp/gmp-${GMP_VERSION}.tar.xz"
MPFR_URL="https://ftp.gnu.org/gnu/mpfr/mpfr-${MPFR_VERSION}.tar.xz"
FLINT_URL="https://github.com/flintlib/flint/archive/v${FLINT_VERSION}.tar.gz"

# Backup URLs
GMP_BACKUP_URL="http://mirrors.kernel.org/gnu/gmp/gmp-${GMP_VERSION}.tar.xz"
MPFR_BACKUP_URL="http://mirrors.kernel.org/gnu/mpfr/mpfr-${MPFR_VERSION}.tar.xz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Safe download function with fallback options
safe_download() {
    local url=$1
    local backup_url=$2
    local filename=$3
    
    # Curl options to fix HTTP2 issues
    local curl_opts=(
        "--http1.1"           # Force HTTP/1.1
        "--retry" "3"         # Retry 3 times
        "--retry-delay" "2"   # Wait 2 seconds between retries
        "--connect-timeout" "30"
        "--max-time" "300"    # 5 minute timeout
        "-L"                  # Follow redirects
        "--fail"              # Fail on HTTP errors
    )
    
    log "Attempting to download $filename..."
    
    # Try primary URL
    if curl "${curl_opts[@]}" -o "$filename" "$url"; then
        success "Downloaded $filename from primary source"
        return 0
    fi
    
    warning "Primary download failed, trying backup URL..."
    
    # Try backup URL
    if [[ -n "$backup_url" ]]; then
        if curl "${curl_opts[@]}" -o "$filename" "$backup_url"; then
            success "Downloaded $filename from backup source"
            return 0
        fi
    fi
    
    error "Failed to download $filename from all sources"
}

# Clean and setup directories
setup_directories() {
    log "Setting up build directories..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR" "$INSTALL_DIR" "$FRAMEWORK_DIR" "$ARCH_DIR" "$BUILD_ARCH_DIR"
    cd "$BUILD_DIR"
}

# Download and extract sources
download_sources() {
    log "Downloading sources..."
    
    # Download GMP
    safe_download "$GMP_URL" "$GMP_BACKUP_URL" "gmp-${GMP_VERSION}.tar.xz"
    tar -xf "gmp-${GMP_VERSION}.tar.xz"
    
    # Download MPFR
    safe_download "$MPFR_URL" "$MPFR_BACKUP_URL" "mpfr-${MPFR_VERSION}.tar.xz"
    tar -xf "mpfr-${MPFR_VERSION}.tar.xz"
    
    # Download FLINT
    safe_download "$FLINT_URL" "" "flint-${FLINT_VERSION}.tar.gz"
    tar -xf "flint-${FLINT_VERSION}.tar.gz"
    mv "flint-${FLINT_VERSION}" flint-src
}

# Set Apple Silicon environment variables
setup_apple_silicon_env() {
    log "Setting up Apple Silicon (arm64) build environment..."
    
    # Set up macOS SDK paths
    local sdk_path
    if ! sdk_path=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null); then
        error "Failed to find macOS SDK"
    fi
    
    local min_version="-mmacosx-version-min=11.0"  # Apple Silicon minimum
    local host_triplet="aarch64-apple-darwin"
    
    # Force Apple Silicon architecture
    export MACOSX_DEPLOYMENT_TARGET="11.0"
    export ARCHPREFERENCE="arm64"
    
    # Apple Silicon specific compiler settings
    export CC="$(xcrun --sdk macosx --find clang) -arch arm64"
    export CXX="$(xcrun --sdk macosx --find clang++) -arch arm64"
    export AR="$(xcrun --sdk macosx --find ar)"
    export RANLIB="$(xcrun --sdk macosx --find ranlib)"
    export STRIP="$(xcrun --sdk macosx --find strip)"
    
    # Apple Silicon specific flags
    export CFLAGS="-arch arm64 -isysroot $sdk_path $min_version -fPIC -O3 -target arm64-apple-macos11"
    export CXXFLAGS="$CFLAGS -stdlib=libc++"
    export LDFLAGS="-arch arm64 -isysroot $sdk_path $min_version -target arm64-apple-macos11"
    export CPPFLAGS="-arch arm64 -isysroot $sdk_path $min_version"
    
    # Configure arguments for Apple Silicon
    CONFIGURE_HOST="--host=aarch64-apple-darwin"
    CONFIGURE_BUILD="--build=aarch64-apple-darwin" 
    CONFIGURE_TARGET="--target=aarch64-apple-darwin"
    
    success "Apple Silicon build environment configured"
}

# Build GMP for Apple Silicon
build_gmp() {
    log "Building GMP for Apple Silicon..."
    cd "$BUILD_ARCH_DIR"
    cp -r "$BUILD_DIR/gmp-${GMP_VERSION}" "gmp-macOS-${ARCH}"
    cd "gmp-macOS-${ARCH}"
    
    # Configure GMP for Apple Silicon
    local gmp_configure_args=(
        "--prefix=$ARCH_DIR"
        "$CONFIGURE_HOST"
        "$CONFIGURE_BUILD"
        "$CONFIGURE_TARGET"
        "--enable-static"
        "--disable-shared"
        "--disable-assembly"  # Safer for cross-compilation
        "--enable-cxx"
    )
    
    if ! ./configure "${gmp_configure_args[@]}"; then
        error "GMP configure failed for Apple Silicon"
    fi
    
    # Build with arch command to ensure arm64
    if ! arch -arm64 make -j$(sysctl -n hw.ncpu); then
        error "GMP build failed for Apple Silicon"
    fi
    
    if ! make install; then
        error "GMP install failed for Apple Silicon"
    fi
    
    success "GMP built successfully for Apple Silicon"
}

# Build MPFR for Apple Silicon
build_mpfr() {
    log "Building MPFR for Apple Silicon..."
    cd "$BUILD_ARCH_DIR"
    cp -r "$BUILD_DIR/mpfr-${MPFR_VERSION}" "mpfr-macOS-${ARCH}"
    cd "mpfr-macOS-${ARCH}"
    
    local mpfr_configure_args=(
        "--prefix=$ARCH_DIR"
        "$CONFIGURE_HOST"
        "$CONFIGURE_BUILD"
        "$CONFIGURE_TARGET"
        "--with-gmp=$ARCH_DIR"
        "--enable-static"
        "--disable-shared"
    )
    
    if ! ./configure "${mpfr_configure_args[@]}"; then
        error "MPFR configure failed for Apple Silicon"
    fi
    
    # Build with arch command to ensure arm64
    if ! arch -arm64 make -j$(sysctl -n hw.ncpu); then
        error "MPFR build failed for Apple Silicon"
    fi
    
    if ! make install; then
        error "MPFR install failed for Apple Silicon"
    fi
    
    success "MPFR built successfully for Apple Silicon"
}

# Build FLINT for Apple Silicon
build_flint() {
    log "Building FLINT for Apple Silicon..."
    cd "$BUILD_ARCH_DIR"
    cp -r "$BUILD_DIR/flint-src" "flint-macOS-${ARCH}"
    cd "flint-macOS-${ARCH}"
    
    # FLINT configure arguments for Apple Silicon
    local flint_configure_args=(
        "--prefix=$ARCH_DIR"
        "$CONFIGURE_HOST"
        "$CONFIGURE_BUILD" 
        "$CONFIGURE_TARGET"
        "--with-gmp=$ARCH_DIR"
        "--with-mpfr=$ARCH_DIR"
        "--enable-static"
        "--disable-shared"
        "--disable-pthread"
    )
    
    if ! ./configure "${flint_configure_args[@]}"; then
        error "FLINT configure failed for Apple Silicon"
    fi
    
    # Build with arch command to ensure arm64
    if ! arch -arm64 make -j$(sysctl -n hw.ncpu); then
        error "FLINT build failed for Apple Silicon"
    fi
    
    if ! make install; then
        error "FLINT install failed for Apple Silicon"
    fi
    
    success "FLINT built successfully for Apple Silicon"
}

# Create framework structure for Apple Silicon
create_framework() {
    local framework_name="FLINT.framework"
    local framework_path="$FRAMEWORK_DIR/$framework_name"
    
    log "Creating Apple Silicon framework..."
    
    mkdir -p "$framework_path/Headers"
    mkdir -p "$framework_path/Modules"
    mkdir -p "$framework_path/Versions/A/Headers"
    mkdir -p "$framework_path/Versions/A/Modules"
    mkdir -p "$framework_path/Versions/A/Resources"
    
    # Copy headers from build
    local headers_source="$ARCH_DIR/include"
    
    if [[ -d "$headers_source/flint" ]]; then
        log "Copying FLINT headers..."
        cp -r "$headers_source/flint"/* "$framework_path/Versions/A/Headers/"
    else
        error "FLINT headers not found at $headers_source/flint"
    fi
    
    if [[ -f "$headers_source/gmp.h" ]]; then
        log "Copying GMP header..."
        cp "$headers_source/gmp.h" "$framework_path/Versions/A/Headers/"
    else
        error "GMP header not found at $headers_source/gmp.h"
    fi
    
    if [[ -f "$headers_source/mpfr.h" ]]; then
        log "Copying MPFR header..."
        cp "$headers_source/mpfr.h" "$framework_path/Versions/A/Headers/"
    else
        error "MPFR header not found at $headers_source/mpfr.h"
    fi
    
    # Create combined static library with all dependencies
    log "Creating combined Apple Silicon static library..."
    local temp_dir="$BUILD_DIR/temp-arm64"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # Extract all object files from static libraries
    local arch_lib_dir="$ARCH_DIR/lib"
    
    if [[ -f "$arch_lib_dir/libflint.a" ]]; then
        ar -x "$arch_lib_dir/libflint.a"
    fi
    if [[ -f "$arch_lib_dir/libgmp.a" ]]; then
        ar -x "$arch_lib_dir/libgmp.a"
    fi
    if [[ -f "$arch_lib_dir/libmpfr.a" ]]; then
        ar -x "$arch_lib_dir/libmpfr.a"
    fi
    
    # Create combined library for arm64
    ar -rcs "$framework_path/Versions/A/FLINT" *.o
    
    # Create symbolic links for proper framework structure
    cd "$framework_path"
    ln -sf "Versions/A/Headers" "Headers"
    ln -sf "Versions/A/Modules" "Modules"
    ln -sf "Versions/A/FLINT" "FLINT"
    ln -sf "Versions/A/Resources" "Resources"
    
    cd "$framework_path/Versions"
    ln -sf "A" "Current"
    
    # Create Info.plist
    cat > "$framework_path/Versions/A/Resources/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>FLINT</string>
    <key>CFBundleIdentifier</key>
    <string>org.flintlib.FLINT</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>FLINT</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>3.3.1</string>
    <key>CFBundleVersion</key>
    <string>3.3.1</string>
    <key>MinimumOSVersion</key>
    <string>11.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>LSRequiresNativeExecution</key>
    <true/>
</dict>
</plist>
EOF

    # Create module.modulemap
    cat > "$framework_path/Versions/A/Modules/module.modulemap" << 'EOF'
framework module FLINT {
    umbrella header "flint.h"
    
    explicit module GMP {
        header "gmp.h"
        export *
    }
    
    explicit module MPFR {
        header "mpfr.h"
        export *
    }
    
    export *
    module * { export * }
}
EOF

    # Create umbrella header if it doesn't exist
    if [[ ! -f "$framework_path/Versions/A/Headers/flint.h" ]]; then
        log "Creating umbrella header..."
        cat > "$framework_path/Versions/A/Headers/flint.h" << 'EOF'
#ifndef FLINT_H
#define FLINT_H

// Include all FLINT headers
#include "flint/flint.h"
#include "flint/fmpz.h"
#include "flint/fmpq.h"
#include "flint/fmpz_poly.h"
#include "flint/fmpq_poly.h"
#include "flint/nmod_poly.h"
#include "flint/arith.h"

// Include dependencies
#include "gmp.h"
#include "mpfr.h"

#endif /* FLINT_H */
EOF
    fi
    
    # Verify the framework binary is arm64
    log "Verifying framework architecture..."
    if command -v file >/dev/null 2>&1; then
        file "$framework_path/FLINT"
    fi
    if command -v lipo >/dev/null 2>&1; then
        lipo -info "$framework_path/FLINT"
    fi
    
    success "Apple Silicon Framework created at $framework_path"
}

# Main build process
main() {
    log "Starting FLINT Apple Silicon Framework build..."
    log "FLINT: $FLINT_VERSION, GMP: $GMP_VERSION, MPFR: $MPFR_VERSION"
    log "Building for Apple Silicon (arm64) only"
    
    setup_directories
    download_sources
    setup_apple_silicon_env
    
    # Build all components for Apple Silicon
    build_gmp
    build_mpfr
    build_flint
    
    # Create framework
    create_framework
    
    success "\n🎉 FLINT Apple Silicon Framework created successfully!"
    success "📍 Location: $FRAMEWORK_DIR/FLINT.framework"
    success "🏗️  Architecture: Apple Silicon (arm64) native"
    
    log "\n📋 Integration Instructions:"
    log "1. Drag FLINT.framework into your Xcode macOS project"
    log "2. Select 'Embed & Sign' in Frameworks, Libraries, and Embedded Content"
    log "3. Import in your code: #include <FLINT/flint.h>"
    log "4. This framework will only run on Apple Silicon Macs (M1/M2/M3)"
    log "\n✅ Apple Silicon native framework is ready!"
}

# Check dependencies
check_dependencies() {
    log "Checking build dependencies..."
    
    # Check if we're on Apple Silicon
    local machine_arch=$(uname -m)
    if [[ "$machine_arch" != "arm64" ]]; then
        warning "You are not running on Apple Silicon ($machine_arch detected)"
        warning "This script is optimized for Apple Silicon Macs"
    else
        success "Running on Apple Silicon ($machine_arch)"
    fi
    
    command -v xcodebuild >/dev/null 2>&1 || error "Xcode is required (xcodebuild not found)"
    command -v curl >/dev/null 2>&1 || error "curl is required"
    command -v lipo >/dev/null 2>&1 || error "lipo is required (part of Xcode)"
    command -v ar >/dev/null 2>&1 || error "ar is required"
    command -v make >/dev/null 2>&1 || error "make is required"
    
    # Check for Xcode command line tools
    if ! xcode-select -p >/dev/null 2>&1; then
        error "Xcode command line tools not installed. Run: xcode-select --install"
    fi
    
    # Verify macOS SDK is available
    if ! xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
        error "macOS SDK not found. Please install Xcode."
    fi
    
    success "All dependencies found!"
}

# Script entry point
check_dependencies
main "$@"
