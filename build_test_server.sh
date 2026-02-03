#!/bin/bash
#
# TASK_6088 Test Server Build Script
#
# This script builds the test server for vulnerability testing
#
# Usage:
#   ./build_test_server.sh [patched|unpatched]
#
# Default: Uses current thrift compiler (whatever is in PATH)
#

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

MODE="${1:-current}"

echo "================================================================"
echo "  TASK_6088 Test Server Build"
echo "================================================================"
echo ""
echo "Mode: $MODE"
echo ""

# Check for thrift compiler
if ! command -v thrift &> /dev/null; then
    echo "❌ ERROR: 'thrift' compiler not found in PATH"
    echo ""
    echo "Please install Apache Thrift or build from source:"
    echo "  cd /path/to/thrift"
    echo "  ./bootstrap.sh"
    echo "  ./configure"
    echo "  make"
    echo "  sudo make install"
    echo ""
    exit 1
fi

THRIFT_VERSION=$(thrift -version 2>&1)
echo "Thrift compiler: $THRIFT_VERSION"
echo ""

# Clean old generated code
echo "[1/4] Cleaning old generated code..."
rm -rf gen-cpp
mkdir -p gen-cpp

# Generate C++ code from IDL
echo "[2/4] Generating C++ code from test_server.thrift..."
thrift --gen cpp test_server.thrift

if [ ! -d "gen-cpp" ]; then
    echo "❌ ERROR: Code generation failed - gen-cpp directory not created"
    exit 1
fi

echo "      Generated files:"
ls -lh gen-cpp/*.cpp gen-cpp/*.h | awk '{print "        " $9 " (" $5 ")"}'
echo ""

# Compile generated code
echo "[3/4] Compiling generated Thrift types..."
g++ -std=c++11 -c gen-cpp/test_server_types.cpp -o gen-cpp/test_server_types.o \
    -I/usr/include -I/usr/local/include -fPIC

g++ -std=c++11 -c gen-cpp/VulnerabilityTestService.cpp -o gen-cpp/VulnerabilityTestService.o \
    -I/usr/include -I/usr/local/include -fPIC

echo "      Object files created"
echo ""

# Compile server
echo "[4/4] Compiling test server..."
g++ -std=c++11 -o test_server test_server.cpp \
    gen-cpp/test_server_types.o \
    gen-cpp/VulnerabilityTestService.o \
    -I/usr/include -I/usr/local/include \
    -lthrift -lpthread

if [ ! -f "test_server" ]; then
    echo "❌ ERROR: Server compilation failed"
    exit 1
fi

echo ""
echo "================================================================"
echo "✅ BUILD SUCCESSFUL"
echo "================================================================"
echo ""
echo "Server binary: ./test_server"
echo "Binary size:   $(du -h test_server | cut -f1)"
echo ""
echo "To run:"
echo "  ./test_server [port]"
echo ""
echo "To test with exploit:"
echo "  # Terminal 1:"
echo "  ./test_server 9090"
echo ""
echo "  # Terminal 2:"
echo "  python3 exploit_poc.py localhost 9090"
echo ""
echo "================================================================"
echo ""

# Show security status
echo "Security Status:"
echo ""
if grep -q "SIZE_LIMIT" gen-cpp/test_server_types.cpp 2>/dev/null; then
    echo "  ✅ PATCHED - SIZE_LIMIT checks found in generated code"
    echo "     The exploit should be BLOCKED"
else
    echo "  ⚠️  UNPATCHED - No SIZE_LIMIT checks found"
    echo "     The exploit may cause a CRASH"
fi
echo ""
echo "================================================================"
