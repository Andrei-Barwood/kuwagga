#!/bin/zsh

# FLINT Universal Framework Builder with Static Dependencies
# Builds FLINT 3.3.1 with GMP 6.3.0 and MPFR 4.2.2 statically linked for iOS and macOS

set -e

# Configuration - Latest versions as of September 2025
FLINT_VERSION="3.3.1"
GMP_VERSION="6.3.0" 
MPFR_VERSION="4.2.2"

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
INSTALL_DIR="$BUILD_DIR/install"
FRAMEWORK_DIR="$BUILD_DIR/frameworks"

# Platforms and architectures
IOS_ARCHS=("arm64")
SIMULATOR_ARCHS=("x86_64" "arm64")
MACOS_ARCHS=("x86_64" "arm64")

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
    local max_attempts=3
    
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
    mkdir -p "$BUILD_DIR" "$INSTALL_DIR" "$FRAMEWORK_DIR"
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

# Build function for a specific architecture and platform
build_for_arch() {
    local arch=$1
    local platform=$2
    local sdk_name=$3
    
    log "Building for ${platform} ${arch}..."
    
    local arch_dir="$BUILD_DIR/${platform}-${arch}"
    local build_arch_dir="$BUILD_DIR/build-${platform}-${arch}"
    mkdir -p "$arch_dir" "$build_arch_dir"
    
    # Set up SDK paths
    local sdk_path
    if ! sdk_path=$(xcrun --sdk "$sdk_name" --show-sdk-path 2>/dev/null); then
        error "Failed to find SDK for $sdk_name"
    fi
    
    local min_version=""
    local host_triplet=""
    
    case "$platform" in
        "iOS")
            min_version="-mios-version-min=12.0"
            host_triplet="$arch-apple-darwin"
            ;;
        "iOSSimulator")
            min_version="-mios-simulator-version-min=12.0"
            host_triplet="$arch-apple-darwin"
            ;;
        "macOS")
            min_version="-mmacosx-version-min=10.15"
            host_triplet="$arch-apple-darwin"
            ;;
    esac
    
    # Common environment variables
    export CC="$(xcrun --sdk "$sdk_name" --find clang)"
    export CXX="$(xcrun --sdk "$sdk_name" --find clang++)"
    export AR="$(xcrun --sdk "$sdk_name" --find ar)"
    export RANLIB="$(xcrun --sdk "$sdk_name" --find ranlib)"
    export STRIP="$(xcrun --sdk "$sdk_name" --find strip)"
    
    export CFLAGS="-arch $arch -isysroot $sdk_path $min_version -fPIC -O3"
    export CXXFLAGS="$CFLAGS -stdlib=libc++"
    export LDFLAGS="-arch $arch -isysroot $sdk_path $min_version"
    export CPPFLAGS="-arch $arch -isysroot $sdk_path $min_version"
    
    # Build GMP
    log "Building GMP for ${platform} ${arch}..."
    cd "$build_arch_dir"
    cp -r "$BUILD_DIR/gmp-${GMP_VERSION}" "gmp-${platform}-${arch}"
    cd "gmp-${platform}-${arch}"
    
    # Configure GMP with proper host for cross-compilation
    local gmp_configure_args=(
        "--prefix=$arch_dir"
        "--host=$host_triplet"
        "--enable-static"
        "--disable-shared"
        "--disable-assembly"
        "--enable-cxx"
    )
    
    if ! ./configure "${gmp_configure_args[@]}"; then
        error "GMP configure failed for ${platform} ${arch}"
    fi
    
    if ! make -j$(sysctl -n hw.ncpu); then
        error "GMP build failed for ${platform} ${arch}"
    fi
    
    if ! make install; then
        error "GMP install failed for ${platform} ${arch}"
    fi
    
    # Build MPFR
    log "Building MPFR for ${platform} ${arch}..."
    cd "$build_arch_dir"
    cp -r "$BUILD_DIR/mpfr-${MPFR_VERSION}" "mpfr-${platform}-${arch}"
    cd "mpfr-${platform}-${arch}"
    
    local mpfr_configure_args=(
        "--prefix=$arch_dir"
        "--host=$host_triplet"
        "--with-gmp=$arch_dir"
        "--enable-static"
        "--disable-shared"
    )
    
    if ! ./configure "${mpfr_configure_args[@]}"; then
        error "MPFR configure failed for ${platform} ${arch}"
    fi
    
    if ! make -j$(sysctl -n hw.ncpu); then
        error "MPFR build failed for ${platform} ${arch}"
    fi
    
    if ! make install; then
        error "MPFR install failed for ${platform} ${arch}"
    fi
    
    # Build FLINT
    log "Building FLINT for ${platform} ${arch}..."
    cd "$build_arch_dir"
    cp -r "$BUILD_DIR/flint-src" "flint-${platform}-${arch}"
    cd "flint-${platform}-${arch}"
    
    # FLINT configure arguments
    local flint_configure_args=(
        "--prefix=$arch_dir"
        "--with-gmp=$arch_dir"
        "--with-mpfr=$arch_dir"
        "--enable-static"
        "--disable-shared"
        "--disable-pthread"
    )
    
    if ! ./configure "${flint_configure_args[@]}"; then
        error "FLINT configure failed for ${platform} ${arch}"
    fi
    
    if ! make -j$(sysctl -n hw.ncpu); then
        error "FLINT build failed for ${platform} ${arch}"
    fi
    
    if ! make install; then
        error "FLINT install failed for ${platform} ${arch}"
    fi
    
    success "Successfully built for ${platform} ${arch}"
}

# Create framework structure
create_framework() {
    local platform=$1
    local framework_name="FLINT.framework"
    local framework_path="$FRAMEWORK_DIR/${platform}/$framework_name"
    
    log "Creating framework for $platform..."
    
    mkdir -p "$framework_path/Headers"
    mkdir -p "$framework_path/Modules"
    
    # Determine first architecture for header copying
    local first_arch=""
    local archs_array=()
    case "$platform" in
        "iOS")
            first_arch="${IOS_ARCHS[1]}"
            archs_array=("${IOS_ARCHS[@]}")
            ;;
        "iOSSimulator")
            first_arch="${SIMULATOR_ARCHS[1]}"
            archs_array=("${SIMULATOR_ARCHS[@]}")
            ;;
        "macOS")
            first_arch="${MACOS_ARCHS[1]}"
            archs_array=("${MACOS_ARCHS[@]}")
            ;;
    esac
    
    # Copy headers from first architecture build
    local headers_source="$BUILD_DIR/${platform}-${first_arch}/include"
    
    if [[ -d "$headers_source/flint" ]]; then
        log "Copying FLINT headers..."
        cp -r "$headers_source/flint"/* "$framework_path/Headers/"
    else
        error "FLINT headers not found at $headers_source/flint"
    fi
    
    if [[ -f "$headers_source/gmp.h" ]]; then
        log "Copying GMP header..."
        cp "$headers_source/gmp.h" "$framework_path/Headers/"
    else
        error "GMP header not found at $headers_source/gmp.h"
    fi
    
    if [[ -f "$headers_source/mpfr.h" ]]; then
        log "Copying MPFR header..."
        cp "$headers_source/mpfr.h" "$framework_path/Headers/"
    else
        error "MPFR header not found at $headers_source/mpfr.h"
    fi
    
    # Create combined static library with all dependencies
    log "Creating combined static library..."
    local temp_dir="$BUILD_DIR/temp-${platform}"
    mkdir -p "$temp_dir"
    
    # Extract and combine all static libraries
    for arch in "${archs_array[@]}"; do
        local arch_dir="$BUILD_DIR/${platform}-${arch}/lib"
        local arch_temp="$temp_dir/$arch"
        mkdir -p "$arch_temp"
        
        cd "$arch_temp"
        
        # Extract all object files from static libraries
        if [[ -f "$arch_dir/libflint.a" ]]; then
            ar -x "$arch_dir/libflint.a"
        fi
        if [[ -f "$arch_dir/libgmp.a" ]]; then
            ar -x "$arch_dir/libgmp.a"
        fi
        if [[ -f "$arch_dir/libmpfr.a" ]]; then
            ar -x "$arch_dir/libmpfr.a"
        fi
        
        # Create combined library for this architecture
        ar -rcs "$temp_dir/libFLINT-${arch}.a" *.o
    done
    
    # Create universal binary
    local universal_libs=()
    for arch in "${archs_array[@]}"; do
        if [[ -f "$temp_dir/libFLINT-${arch}.a" ]]; then
            universal_libs+=("$temp_dir/libFLINT-${arch}.a")
        fi
    done
    
    if [[ ${#universal_libs[@]} -gt 1 ]]; then
        lipo -create "${universal_libs[@]}" -output "$framework_path/FLINT"
    elif [[ ${#universal_libs[@]} -eq 1 ]]; then
        cp "${universal_libs[0]}" "$framework_path/FLINT"
    else
        error "No libraries found to create framework binary"
    fi
    
    # Create Info.plist
    cat > "$framework_path/Info.plist" << EOF
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
    <string>${FLINT_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${FLINT_VERSION}</string>
    <key>MinimumOSVersion</key>
    <string>12.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>$(case "$platform" in
            "iOS") echo "iPhoneOS" ;;
            "iOSSimulator") echo "iPhoneSimulator" ;;
            "macOS") echo "MacOSX" ;;
        esac)</string>
    </array>
</dict>
</plist>
EOF

    # Create module.modulemap
    cat > "$framework_path/Modules/module.modulemap" << EOF
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
    if [[ ! -f "$framework_path/Headers/flint.h" ]]; then
        log "Creating umbrella header..."
        cat > "$framework_path/Headers/flint.h" << EOF
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
    
    success "Framework created for $platform at $framework_path"
}

# Create XCFramework
create_xcframework() {
    log "Creating XCFramework..."
    
    local xcframework_path="$FRAMEWORK_DIR/FLINT.xcframework"
    rm -rf "$xcframework_path"
    
    # Build xcodebuild command
    local xcodebuild_args=(
        "-create-xcframework"
        "-framework" "$FRAMEWORK_DIR/iOS/FLINT.framework"
        "-framework" "$FRAMEWORK_DIR/iOSSimulator/FLINT.framework"
        "-framework" "$FRAMEWORK_DIR/macOS/FLINT.framework"
        "-output" "$xcframework_path"
    )
    
    if ! xcodebuild "${xcodebuild_args[@]}"; then
        error "Failed to create XCFramework"
    fi
    
    success "XCFramework created at $xcframework_path"
}

# Main build process
main() {
    log "Starting FLINT Universal Framework build..."
    log "FLINT: $FLINT_VERSION, GMP: $GMP_VERSION, MPFR: $MPFR_VERSION"
    
    setup_directories
    download_sources
    
    # Build for all platforms and architectures
    log "Building for iOS architectures..."
    for arch in "${IOS_ARCHS[@]}"; do
        build_for_arch "$arch" "iOS" "iphoneos"
    done
    
    log "Building for iOS Simulator architectures..."
    for arch in "${SIMULATOR_ARCHS[@]}"; do
        build_for_arch "$arch" "iOSSimulator" "iphonesimulator"
    done
    
    log "Building for macOS architectures..."
    for arch in "${MACOS_ARCHS[@]}"; do
        build_for_arch "$arch" "macOS" "macosx"
    done
    
    # Create frameworks
    create_framework "iOS"
    create_framework "iOSSimulator" 
    create_framework "macOS"
    
    # Create XCFramework
    create_xcframework
    
    success "\n🎉 FLINT.xcframework created successfully!"
    success "📍 Location: $FRAMEWORK_DIR/FLINT.xcframework"
    success "📁 Individual frameworks: $FRAMEWORK_DIR/"
    
    log "\n📋 Integration Instructions:"
    log "1. Drag FLINT.xcframework into your Xcode project"
    log "2. Select 'Embed & Sign' in Frameworks, Libraries, and Embedded Content"
    log "3. Import in your code: #include <FLINT/flint.h>"
    log "\n✅ Framework is ready for integration into Xcode projects!"
}

# Check dependencies
check_dependencies() {
    log "Checking build dependencies..."
    
    command -v xcodebuild >/dev/null 2>&1 || error "Xcode is required (xcodebuild not found)"
    command -v curl >/dev/null 2>&1 || error "curl is required"
    command -v lipo >/dev/null 2>&1 || error "lipo is required (part of Xcode)"
    command -v ar >/dev/null 2>&1 || error "ar is required"
    command -v make >/dev/null 2>&1 || error "make is required"
    
    # Check for Xcode command line tools
    if ! xcode-select -p >/dev/null 2>&1; then
        error "Xcode command line tools not installed. Run: xcode-select --install"
    fi
    
    success "All dependencies found!"
}

# Script entry point
check_dependencies
main "$@"
