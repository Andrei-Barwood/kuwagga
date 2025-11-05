#!/usr/bin/env zsh

# ============================================================================
# Mithril Network Layer - Project Structure Setup Script
# ============================================================================
# Author: Andrei Barwood
# Description: Creates directory structure and placeholder files for Mithril
#              cryptographic network layer with libsodium integration
# Usage: ./setup_project.zsh
# ============================================================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Project metadata
readonly PROJECT_NAME="Mithril"
readonly VERSION="2.1.0"
readonly TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# ============================================================================
# Utility Functions
# ============================================================================

print_header() {
    echo "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                  MITHRIL PROJECT SETUP                        ║"
    echo "║        Cryptographic Network Layer for IoT Devices            ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo "${NC}"
    echo "${BLUE}Version:${NC} ${VERSION}"
    echo "${BLUE}Date:${NC}    ${TIMESTAMP}"
    echo ""
}

print_section() {
    echo ""
    echo "${MAGENTA}▶ $1${NC}"
    echo "${MAGENTA}$(printf '─%.0s' {1..60})${NC}"
}

print_success() {
    echo "${GREEN}✓${NC} $1"
}

print_warning() {
    echo "${YELLOW}⚠${NC}  $1"
}

print_error() {
    echo "${RED}✗${NC} $1"
}

create_directory() {
    local dir=$1
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        print_success "Created directory: ${dir}"
    else
        print_warning "Directory already exists: ${dir}"
    fi
}

create_file() {
    local file=$1
    local content=$2
    
    if [[ ! -f "$file" ]]; then
        if [[ -n "$content" ]]; then
            echo "$content" > "$file"
        else
            touch "$file"
        fi
        print_success "Created file: ${file}"
    else
        print_warning "File already exists: ${file}"
    fi
}

# ============================================================================
# Directory Structure Creation
# ============================================================================

create_project_structure() {
    print_section "Creating Base Directory Structure"
    
    # Root directories
    create_directory "."
    
    # ========================================================================
    # EXISTING STRUCTURE (from your Mithril repo)
    # ========================================================================
    
    print_section "Setting up existing Mithril components"
    
    # ASIC Implementation (Hardware)
    create_directory "ASIC_implementation"
    create_directory "ASIC_implementation/v2.1-1"
    create_directory "ASIC_implementation/v2.1-2"
    create_directory "ASIC_implementation/synthesis"
    create_directory "ASIC_implementation/simulation"
    
    # Testbench (Verification)
    create_directory "testbench"
    create_directory "testbench/unit_tests"
    create_directory "testbench/integration_tests"
    create_directory "testbench/vectors"
    
    # XCode Project (Framework generation)
    create_directory "XCode_Project"
    create_directory "XCode_Project/Mithril.xcodeproj"
    create_directory "XCode_Project/Mithril"
    create_directory "XCode_Project/MithrilTests"
    
    # ========================================================================
    # NEW STRUCTURE (Network Layer + libsodium)
    # ========================================================================
    
    print_section "Setting up new Network Layer components"
    
    # Core crypto library (FLINT based)
    create_directory "crypto"
    create_directory "crypto/include"
    create_directory "crypto/src"
    create_directory "crypto/flint"
    
    # Network layer (Boost.Asio + libsodium)
    create_directory "network"
    create_directory "network/include"
    create_directory "network/include/mithril"
    create_directory "network/src"
    create_directory "network/protocols"
    
    # Examples and demos
    create_directory "examples"
    create_directory "examples/basic"
    create_directory "examples/iot_devices"
    create_directory "examples/tidal_energy"
    
    # Tests
    create_directory "tests"
    create_directory "tests/unit"
    create_directory "tests/integration"
    create_directory "tests/performance"
    create_directory "tests/security"
    
    # Build system
    create_directory "build"
    create_directory "cmake"
    create_directory "cmake/modules"
    
    # Documentation
    create_directory "docs"
    create_directory "docs/api"
    create_directory "docs/tutorials"
    create_directory "docs/architecture"
    
    # Scripts and tools
    create_directory "scripts"
    create_directory "scripts/build"
    create_directory "scripts/deployment"
    create_directory "scripts/testing"
    
    # Framework output
    create_directory "frameworks"
    create_directory "frameworks/iOS"
    create_directory "frameworks/macOS"
    
    # Certificates and keys (for testing)
    create_directory "certs"
    create_directory "certs/dev"
    create_directory "certs/prod"
}

# ============================================================================
# File Creation
# ============================================================================

create_project_files() {
    print_section "Creating Core Files"
    
    # ========================================================================
    # Root level files
    # ========================================================================
    
    create_file "README.md" "# Mithril Network Layer
    
Cryptographic network layer for IoT devices in tidal energy systems.

## Features
- FLINT-based advanced cryptography
- libsodium for modern AEAD primitives
- Boost.Asio C++20 async networking
- iOS/macOS framework generation

## Build
\`\`\`bash
./scripts/build/build_all.zsh
\`\`\`

See \`docs/\` for detailed documentation.
"
    
    create_file ".gitignore" "# Build artifacts
build/
*.o
*.a
*.so
*.dylib
*.framework

# IDE
.vscode/
.idea/
*.xcworkspace
xcuserdata/

# Generated
*.log
*.tmp
certs/*.key
certs/*.crt
!certs/dev/.gitkeep

# macOS
.DS_Store
"
    
    create_file "CMakeLists.txt" ""
    create_file "LICENSE" ""
    create_file "CHANGELOG.md" ""
    
    # ========================================================================
    # Crypto layer (FLINT)
    # ========================================================================
    
    print_section "Creating Crypto Layer Files"
    
    create_file "crypto/include/mithril_crypto.h" ""
    create_file "crypto/include/flint_wrapper.h" ""
    create_file "crypto/src/mithril_crypto.c" ""
    create_file "crypto/src/flint_wrapper.c" ""
    create_file "crypto/CMakeLists.txt" ""
    
    # ========================================================================
    # Network layer (libsodium + Boost.Asio)
    # ========================================================================
    
    print_section "Creating Network Layer Files"
    
    # Headers
    create_file "network/include/mithril/mithril_sodium.hpp" ""
    create_file "network/include/mithril/secure_session.hpp" ""
    create_file "network/include/mithril/secure_acceptor.hpp" ""
    create_file "network/include/mithril/key_exchange.hpp" ""
    create_file "network/include/mithril/stream_encryption.hpp" ""
    create_file "network/include/mithril/digital_signature.hpp" ""
    create_file "network/include/mithril/crypto_hash.hpp" ""
    
    # Implementation
    create_file "network/src/secure_session.cpp" ""
    create_file "network/src/secure_acceptor.cpp" ""
    create_file "network/src/key_exchange.cpp" ""
    create_file "network/src/stream_encryption.cpp" ""
    
    # Protocol definitions
    create_file "network/protocols/iot_protocol.hpp" ""
    create_file "network/protocols/tidal_sensor_protocol.hpp" ""
    
    create_file "network/CMakeLists.txt" ""
    
    # ========================================================================
    # Examples (converted from Boost.Asio cookbook)
    # ========================================================================
    
    print_section "Creating Example Files"
    
    # Basic examples
    create_file "examples/basic/accepting_connection_sodium.cpp" ""
    create_file "examples/basic/connecting_client_sodium.cpp" ""
    create_file "examples/basic/echo_server_sodium.cpp" ""
    create_file "examples/basic/async_server_sodium.cpp" ""
    
    # IoT specific
    create_file "examples/iot_devices/sensor_client.cpp" ""
    create_file "examples/iot_devices/gateway_server.cpp" ""
    create_file "examples/iot_devices/device_simulator.cpp" ""
    
    # Tidal energy specific
    create_file "examples/tidal_energy/tidal_sensor_server.cpp" ""
    create_file "examples/tidal_energy/control_panel_client.cpp" ""
    create_file "examples/tidal_energy/data_aggregator.cpp" ""
    
    create_file "examples/CMakeLists.txt" ""
    
    # ========================================================================
    # Tests
    # ========================================================================
    
    print_section "Creating Test Files"
    
    # Unit tests
    create_file "tests/unit/test_key_exchange.cpp" ""
    create_file "tests/unit/test_encryption.cpp" ""
    create_file "tests/unit/test_signatures.cpp" ""
    create_file "tests/unit/test_hash.cpp" ""
    
    # Integration tests
    create_file "tests/integration/test_full_handshake.cpp" ""
    create_file "tests/integration/test_concurrent_sessions.cpp" ""
    create_file "tests/integration/test_error_handling.cpp" ""
    
    # Performance tests
    create_file "tests/performance/benchmark_encryption.cpp" ""
    create_file "tests/performance/benchmark_throughput.cpp" ""
    create_file "tests/performance/benchmark_latency.cpp" ""
    
    # Security tests
    create_file "tests/security/test_replay_attack.cpp" ""
    create_file "tests/security/test_mitm_protection.cpp" ""
    create_file "tests/security/fuzz_protocol.cpp" ""
    
    create_file "tests/CMakeLists.txt" ""
    
    # ========================================================================
    # Build system
    # ========================================================================
    
    print_section "Creating Build System Files"
    
    create_file "cmake/modules/FindFLINT.cmake" ""
    create_file "cmake/modules/Findsodium.cmake" ""
    create_file "cmake/CompilerWarnings.cmake" ""
    create_file "cmake/Sanitizers.cmake" ""
    
    # ========================================================================
    # Scripts
    # ========================================================================
    
    print_section "Creating Build Scripts"
    
    create_file "scripts/build/build_all.zsh" "#!/usr/bin/env zsh
# Build entire project
set -euo pipefail

mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j\$(nproc)
"
    
    create_file "scripts/build/build_framework_ios.zsh" "#!/usr/bin/env zsh
# Build iOS framework
set -euo pipefail

xcodebuild -project XCode_Project/Mithril.xcodeproj \\
    -scheme Mithril \\
    -configuration Release \\
    -sdk iphoneos \\
    -destination 'generic/platform=iOS' \\
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES
"
    
    create_file "scripts/testing/run_all_tests.zsh" "#!/usr/bin/env zsh
# Run all tests
set -euo pipefail

cd build
ctest --output-on-failure
"
    
    create_file "scripts/deployment/generate_certs.zsh" "#!/usr/bin/env zsh
# Generate development certificates
set -euo pipefail

openssl req -x509 -newkey rsa:4096 -keyout certs/dev/server.key \\
    -out certs/dev/server.crt -days 365 -nodes \\
    -subj '/CN=mithril-dev'
"
    
    # Make scripts executable
    chmod +x scripts/build/*.zsh
    chmod +x scripts/testing/*.zsh
    chmod +x scripts/deployment/*.zsh
    
    # ========================================================================
    # Documentation
    # ========================================================================
    
    print_section "Creating Documentation Files"
    
    create_file "docs/GETTING_STARTED.md" ""
    create_file "docs/ARCHITECTURE.md" ""
    create_file "docs/API_REFERENCE.md" ""
    
    create_file "docs/architecture/network_layer.md" ""
    create_file "docs/architecture/crypto_layer.md" ""
    create_file "docs/architecture/security_model.md" ""
    
    create_file "docs/tutorials/basic_server.md" ""
    create_file "docs/tutorials/iot_integration.md" ""
    create_file "docs/tutorials/framework_usage.md" ""
    
    # ========================================================================
    # Git keep files for empty directories
    # ========================================================================
    
    print_section "Creating .gitkeep files"
    
    create_file "build/.gitkeep" ""
    create_file "certs/dev/.gitkeep" ""
    create_file "certs/prod/.gitkeep" ""
    create_file "frameworks/iOS/.gitkeep" ""
    create_file "frameworks/macOS/.gitkeep" ""
}

# ============================================================================
# Project State Tracking
# ============================================================================

create_state_file() {
    print_section "Creating Project State Tracker"
    
    local state_file=".mithril_project_state.json"
    
    cat > "$state_file" << EOF
{
  "project": "${PROJECT_NAME}",
  "version": "${VERSION}",
  "created": "${TIMESTAMP}",
  "structure_version": "1.0.0",
  "components": {
    "crypto_layer": {
      "status": "initialized",
      "files_count": $(find crypto -type f 2>/dev/null | wc -l | tr -d ' ')
    },
    "network_layer": {
      "status": "initialized",
      "files_count": $(find network -type f 2>/dev/null | wc -l | tr -d ' ')
    },
    "examples": {
      "status": "initialized",
      "files_count": $(find examples -type f 2>/dev/null | wc -l | tr -d ' ')
    },
    "tests": {
      "status": "initialized",
      "files_count": $(find tests -type f 2>/dev/null | wc -l | tr -d ' ')
    }
  },
  "next_steps": [
    "Implement crypto/include/mithril_crypto.h",
    "Implement network/include/mithril/mithril_sodium.hpp",
    "Convert first Boost.Asio example",
    "Setup CMake build system",
    "Generate test certificates"
  ]
}
EOF
    
    print_success "Created state file: ${state_file}"
}

# ============================================================================
# Summary Report
# ============================================================================

print_summary() {
    print_section "Setup Summary"
    
    local total_dirs=$(find . -type d | wc -l | tr -d ' ')
    local total_files=$(find . -type f | wc -l | tr -d ' ')
    
    echo "${GREEN}Project setup completed successfully!${NC}"
    echo ""
    echo "${BLUE}Statistics:${NC}"
    echo "  • Directories created: ${total_dirs}"
    echo "  • Files created:       ${total_files}"
    echo ""
    echo "${BLUE}Next Steps:${NC}"
    echo "  1. Review project structure"
    echo "  2. Start implementing crypto layer"
    echo "  3. Convert Boost.Asio examples"
    echo "  4. Build and test"
    echo ""
    echo "${YELLOW}Quick Start:${NC}"
    echo "  ${CYAN}./scripts/build/build_all.zsh${NC}          # Build project"
    echo "  ${CYAN}./scripts/testing/run_all_tests.zsh${NC}   # Run tests"
    echo "  ${CYAN}./scripts/deployment/generate_certs.zsh${NC} # Generate dev certs"
    echo ""
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    print_header
    
    # Check if we're in the right directory
    if [[ -f ".mithril_project_state.json" ]]; then
        print_warning "Project already initialized in this directory"
        read "REPLY?Do you want to continue? (y/N): "
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 0
        fi
    fi
    
    # Create structure
    create_project_structure
    
    # Create files
    create_project_files
    
    # Create state tracking
    create_state_file
    
    # Print summary
    print_summary
    
    echo "${GREEN}Setup complete! 🚀${NC}"
}

# Run main function
main "$@"
