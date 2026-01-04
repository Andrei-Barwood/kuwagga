#!/bin/zsh

# FLINT Apple Silicon Framework Builder with Static Dependencies
# Builds FLINT 3.3.1 with GMP 6.3.0 and MPFR 4.2.2 statically linked for Apple Silicon (arm64) only

set -euo pipefail

# Configuration - Latest versions as of September 2025
FLINT_VERSION="3.3.1"
GMP_VERSION="6.3.0" 
MPFR_VERSION="4.2.2"

# FIXED: Use build directory without spaces to avoid libtool issues
SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
BUILD_BASE="$SCRIPT_DIR/flint_build_$(date +%s)"  # Use timestamp for uniqueness
BUILD_DIR="$BUILD_BASE/build"
INSTALL_DIR="$BUILD_DIR/install"
FRAMEWORK_DIR="$BUILD_DIR/frameworks"

# Apple Silicon (arm64) only - use absolute paths
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

# FIXED: Clean and setup directories without spaces
setup_directories() {
    log "Setting up build directories..."
    log "Build base directory: $BUILD_BASE"
    
    # Remove any existing build directory
    rm -rf "$BUILD_BASE"
    
    # Create build directory structure without spaces in path
    mkdir -p "$BUILD_BASE" "$BUILD_DIR" "$INSTALL_DIR" "$FRAMEWORK_DIR" "$ARCH_DIR" "$BUILD_ARCH_DIR"
    
    # Verify paths don't contain spaces
    if [[ "$BUILD_DIR" =~ [[:space:]] ]]; then
        error "Build directory path contains spaces: $BUILD_DIR"
    fi
    
    cd "$BUILD_DIR"
    success "Build directories created at: $BUILD_DIR"
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

# Set Apple Silicon environment variables - ENHANCED
setup_apple_silicon_env() {
    log "Setting up Apple Silicon (arm64) build environment..."
    
    # Check Command Line Tools installation
    if ! xcode-select -p >/dev/null 2>&1; then
        error "Xcode Command Line Tools not found. Please run: xcode-select --install"
    fi
    
    # Get SDK path - try multiple locations
    local sdk_path=""
    if [[ -n "$(xcrun --sdk macosx --show-sdk-path 2>/dev/null)" ]]; then
        sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
    elif [[ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk" ]]; then
        sdk_path="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
    elif [[ -d "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk" ]]; then
        sdk_path="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    else
        error "Could not find macOS SDK. Please reinstall Command Line Tools: sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install"
    fi
    
    log "Using macOS SDK: $sdk_path"
    
    # Verify SDK exists and is readable
    if [[ ! -d "$sdk_path" ]]; then
        error "SDK path does not exist: $sdk_path"
    fi
    
    # Set deployment target for Apple Silicon
    export MACOSX_DEPLOYMENT_TARGET="11.0"
    
    # Set up compiler toolchain - ENHANCED
    export CC="$(xcrun --find clang)"
    export CXX="$(xcrun --find clang++)"
    export AR="$(xcrun --find ar)"
    export RANLIB="$(xcrun --find ranlib)"
    export STRIP="$(xcrun --find strip)"
    export LIBTOOL="$(xcrun --find libtool)"
    export NM="$(xcrun --find nm)"
    
    # Verify compiler exists
    if [[ ! -x "$CC" ]]; then
        error "Clang compiler not found at: $CC"
    fi
    
    # Use arrays for proper flag handling
    CFLAGS_ARRAY=(
        "-arch" "arm64"
        "-isysroot" "$sdk_path"
        "-mmacosx-version-min=11.0"
        "-O3"
        "-fno-stack-check"
    )
    
    CXXFLAGS_ARRAY=(
        "-arch" "arm64"
        "-isysroot" "$sdk_path"
        "-mmacosx-version-min=11.0"
        "-O3"
        "-fno-stack-check"
        "-stdlib=libc++"
    )
    
    LDFLAGS_ARRAY=(
        "-arch" "arm64"
        "-isysroot" "$sdk_path"
        "-mmacosx-version-min=11.0"
    )
    
    CPPFLAGS_ARRAY=(
        "-arch" "arm64"
        "-isysroot" "$sdk_path"
    )
    
    # Export as strings for configure scripts (they expect string variables)
    export CFLAGS="${CFLAGS_ARRAY[*]}"
    export CXXFLAGS="${CXXFLAGS_ARRAY[*]}"
    export LDFLAGS="${LDFLAGS_ARRAY[*]}"
    export CPPFLAGS="${CPPFLAGS_ARRAY[*]}"
    
    # Build and host triplets for Apple Silicon
    export BUILD_TRIPLET="arm64-apple-darwin"
    export HOST_TRIPLET="arm64-apple-darwin"
    
    success "Apple Silicon build environment configured"
    success "CC: $CC"
    success "SDK: $sdk_path"
    success "Build directory (no spaces): $BUILD_DIR"
}

# Enhanced compiler test using arrays
test_compiler() {
    log "Testing compiler configuration..."
    
    # Create a proper test file instead of using /dev/null
    local test_file="$BUILD_DIR/compiler_test.c"
    cat > "$test_file" << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello, World!\n");
    return 0;
}
EOF
    
    local test_output="$BUILD_DIR/compiler_test"
    
    # Test compilation using array expansion
    log "Testing compiler with flags..."
    if ! "$CC" "${CFLAGS_ARRAY[@]}" "$test_file" -o "$test_output" 2>"$BUILD_DIR/compiler_test.log"; then
        error "Compiler test failed. Error output:"$'\n'"$(cat "$BUILD_DIR/compiler_test.log")"
    fi
    
    # Test if the binary was created and is executable
    if [[ ! -x "$test_output" ]]; then
        error "Compiler test produced no executable output"
    fi
    
    # Test if it runs (optional)
    if ! "$test_output" >/dev/null 2>&1; then
        warning "Compiled test program doesn't run correctly, but continuing..."
    fi
    
    # Verify architecture
    if command -v file >/dev/null 2>&1; then
        local arch_info=$(file "$test_output")
        log "Test binary architecture: $arch_info"
        if [[ ! "$arch_info" =~ "arm64" ]]; then
            warning "Test binary may not be arm64 architecture"
        fi
    fi
    
    # Clean up test files
    rm -f "$test_file" "$test_output"
    
    success "Compiler test passed"
}

# ENHANCED: Build GMP with better path handling and verification
build_gmp() {
    log "Building GMP for Apple Silicon..."
    cd "$BUILD_ARCH_DIR"
    cp -r "$BUILD_DIR/gmp-${GMP_VERSION}" "gmp-macOS-${ARCH}"
    cd "gmp-macOS-${ARCH}"
    
    # Verify we're in a directory without spaces
    local current_dir="$(pwd)"
    if [[ "$current_dir" =~ [[:space:]] ]]; then
        error "Current build directory contains spaces: $current_dir"
    fi
    
    # Test compiler in GMP build directory
    test_compiler
    
    # Configure for Apple Silicon
    local gmp_configure_args=(
        "--prefix=$ARCH_DIR"
        "--build=$BUILD_TRIPLET"
        "--host=$HOST_TRIPLET" 
        "--enable-static"
        "--disable-shared"
        "--disable-cxx"       # Disable C++ to avoid issues
        "--disable-assembly"  # Safer for cross-compilation
        "ABI=64"
    )
    
    log "Configuring GMP with args: ${gmp_configure_args[*]}"
    log "Install prefix: $ARCH_DIR"
    
    if ! ./configure "${gmp_configure_args[@]}" 2>&1 | tee configure.log; then
        log "GMP configure failed. Checking config.log..."
        if [[ -f config.log ]]; then
            echo "=== Last 50 lines of config.log ==="
            tail -50 config.log
        fi
        error "GMP configure failed for Apple Silicon. Check configure.log and config.log"
    fi
    
    # Build
    if ! make -j$(sysctl -n hw.ncpu) 2>&1 | tee make.log; then
        error "GMP build failed for Apple Silicon. Check make.log"
    fi
    
    # Test (optional but recommended)
    if ! make check 2>&1 | tee check.log; then
        warning "GMP tests failed, but continuing..."
    fi
    
    # Install with verbose output
    log "Installing GMP to: $ARCH_DIR"
    if ! make install 2>&1 | tee install.log; then
        log "=== Last 20 lines of install.log ==="
        tail -20 install.log
        error "GMP install failed for Apple Silicon. Check install.log"
    fi
    
    # ENHANCED: Verify the library was built correctly with multiple search paths
    local gmp_lib_paths=(
        "$ARCH_DIR/lib/libgmp.a"
        "$ARCH_DIR/lib64/libgmp.a"
        "$(find "$ARCH_DIR" -name "libgmp.a" 2>/dev/null | head -1)"
    )
    
    local gmp_lib_found=""
    for lib_path in "${gmp_lib_paths[@]}"; do
        if [[ -f "$lib_path" ]]; then
            gmp_lib_found="$lib_path"
            break
        fi
    done
    
    if [[ -z "$gmp_lib_found" ]]; then
        log "=== Contents of $ARCH_DIR ==="
        find "$ARCH_DIR" -name "*gmp*" -type f 2>/dev/null || true
        error "GMP static library not found. Expected at: ${gmp_lib_paths[*]}"
    fi
    
    log "Found GMP library at: $gmp_lib_found"
    
    # Check architecture of built library
    if command -v file >/dev/null 2>&1; then
        log "GMP library architecture:"
        file "$gmp_lib_found"
    fi
    
    success "GMP built successfully for Apple Silicon"
}

# Build MPFR for Apple Silicon
build_mpfr() {
    log "Building MPFR for Apple Silicon..."
    cd "$BUILD_ARCH_DIR"
    cp -r "$BUILD_DIR/mpfr-${MPFR_VERSION}" "mpfr-macOS-${ARCH}"
    cd "mpfr-macOS-${ARCH}"
    
    # Set dependency paths
    export CPPFLAGS="$CPPFLAGS -I$ARCH_DIR/include"
    export LDFLAGS="$LDFLAGS -L$ARCH_DIR/lib"
    
    local mpfr_configure_args=(
        "--prefix=$ARCH_DIR"
        "--build=$BUILD_TRIPLET"
        "--host=$HOST_TRIPLET"
        "--with-gmp=$ARCH_DIR"
        "--enable-static"
        "--disable-shared"
    )
    
    log "Configuring MPFR with args: ${mpfr_configure_args[*]}"
    
    if ! ./configure "${mpfr_configure_args[@]}" 2>&1 | tee configure.log; then
        error "MPFR configure failed for Apple Silicon. Check configure.log"
    fi
    
    if ! make -j$(sysctl -n hw.ncpu) 2>&1 | tee make.log; then
        error "MPFR build failed for Apple Silicon. Check make.log"
    fi
    
    if ! make check 2>&1 | tee check.log; then
        warning "MPFR tests failed, but continuing..."
    fi
    
    if ! make install 2>&1 | tee install.log; then
        error "MPFR install failed for Apple Silicon. Check install.log"
    fi
    
    # Verify the library was built correctly
    if [[ ! -f "$ARCH_DIR/lib/libmpfr.a" ]]; then
        log "=== Contents of $ARCH_DIR/lib ==="
        ls -la "$ARCH_DIR/lib/" 2>/dev/null || true
        error "MPFR static library not found at $ARCH_DIR/lib/libmpfr.a"
    fi
    
    success "MPFR built successfully for Apple Silicon"
}

# Build FLINT for Apple Silicon
build_flint() {
    log "Building FLINT for Apple Silicon..."
    cd "$BUILD_ARCH_DIR"
    cp -r "$BUILD_DIR/flint-src" "flint-macOS-${ARCH}"
    cd "flint-macOS-${ARCH}"
    
    # Set dependency paths
    export CPPFLAGS="$CPPFLAGS -I$ARCH_DIR/include"
    export LDFLAGS="$LDFLAGS -L$ARCH_DIR/lib"
    
    # FLINT configure arguments for Apple Silicon
    local flint_configure_args=(
        "--prefix=$ARCH_DIR"
        "--with-gmp=$ARCH_DIR"
        "--with-mpfr=$ARCH_DIR"
        "--enable-static"
        "--disable-shared"
        "--disable-pthread"
    )
    
    log "Configuring FLINT with args: ${flint_configure_args[*]}"
    
    if ! ./configure "${flint_configure_args[@]}" 2>&1 | tee configure.log; then
        error "FLINT configure failed for Apple Silicon. Check configure.log"
    fi
    
    if ! make -j$(sysctl -n hw.ncpu) 2>&1 | tee make.log; then
        error "FLINT build failed for Apple Silicon. Check make.log"
    fi
    
    if ! make install 2>&1 | tee install.log; then
        error "FLINT install failed for Apple Silicon. Check install.log"
    fi
    
    # Verify the library was built correctly
    if [[ ! -f "$ARCH_DIR/lib/libflint.a" ]]; then
        log "=== Contents of $ARCH_DIR/lib ==="
        ls -la "$ARCH_DIR/lib/" 2>/dev/null || true
        error "FLINT static library not found at $ARCH_DIR/lib/libflint.a"
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
    
    # Copy framework to original script directory for easy access
    local output_framework="$SCRIPT_DIR/FLINT.framework"
    if [[ -d "$output_framework" ]]; then
        rm -rf "$output_framework"
    fi
    cp -r "$framework_path" "$output_framework"
    
    # Verify the framework binary is arm64
    log "Verifying framework architecture..."
    if command -v file >/dev/null 2>&1; then
        file "$output_framework/FLINT"
    fi
    if command -v lipo >/dev/null 2>&1; then
        lipo -info "$output_framework/FLINT"
    fi
    
    success "Apple Silicon Framework created at $output_framework"
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
    success "📍 Location: $SCRIPT_DIR/FLINT.framework"
    success "🏗️  Architecture: Apple Silicon (arm64) native"
    
    log "\n📋 Integration Instructions:"
    log "1. Drag FLINT.framework into your Xcode macOS project"
    log "2. Select 'Embed & Sign' in Frameworks, Libraries, and Embedded Content"
    log "3. Import in your code: #include <FLINT/flint.h>"
    log "4. This framework will only run on Apple Silicon Macs (M1/M2/M3)"
    
    # Clean up build directory (optional)
    log "\n🧹 Cleaning up build directory..."
    rm -rf "$BUILD_BASE"
    log "Build directory cleaned: $BUILD_BASE"
    
    log "\n✅ Apple Silicon native framework is ready!"
}

# Check dependencies - ENHANCED
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
    
    # Enhanced Command Line Tools check
    if ! xcode-select -p >/dev/null 2>&1; then
        error "Xcode Command Line Tools not installed. Please run: xcode-select --install"
    fi
    
    local clt_path="$(xcode-select -p)"
    log "Command Line Tools path: $clt_path"
    
    # Check for basic tools
    command -v curl >/dev/null 2>&1 || error "curl is required"
    command -v lipo >/dev/null 2>&1 || error "lipo is required (part of Xcode)"
    command -v ar >/dev/null 2>&1 || error "ar is required"
    command -v make >/dev/null 2>&1 || error "make is required"
    
    # Check clang specifically
    if ! command -v clang >/dev/null 2>&1; then
        error "clang compiler not found. Command Line Tools may need reinstalling: sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install"
    fi
    
    # Verify clang version
    local clang_version=$(clang --version 2>/dev/null | head -1)
    log "Clang version: $clang_version"
    
    success "All dependencies found!"
}

# Script entry point
check_dependencies
main "$@"
