#!/bin/bash
#
# TASK_6088 Test Runner
#
# This script runs the complete test: server + exploit
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

MODE="${1:-unpatched}"
PORT=9090

echo "================================================================"
echo "  TASK_6088 Vulnerability Test"
echo "================================================================"
echo ""

# Test 1: Unpatched server
echo "TEST 1: UNPATCHED SERVER (Vulnerable)"
echo "======================================"
echo ""
echo "Starting unpatched server on port $PORT..."

# Start server in background
python3 simple_test_server.py $PORT > server_unpatched.log 2>&1 &
SERVER_PID=$!

# Wait for server to start
sleep 2

# Check if server is running
if ! ps -p $SERVER_PID > /dev/null 2>&1; then
    echo "❌ Server failed to start"
    cat server_unpatched.log
    exit 1
fi

echo "✅ Server started (PID: $SERVER_PID)"
echo ""

# Run exploit
echo "Running exploit..."
echo ""
python3 exploit_poc.py localhost $PORT > exploit_unpatched.log 2>&1 || true

# Kill server
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

echo ""
echo "Server output:"
echo "--------------"
cat server_unpatched.log
echo ""
echo "Exploit output:"
echo "---------------"
cat exploit_unpatched.log
echo ""

# Small delay
sleep 2

echo ""
echo "================================================================"
echo ""

# Test 2: Patched server
echo "TEST 2: PATCHED SERVER (Protected)"
echo "==================================="
echo ""
echo "Starting patched server on port $PORT..."

# Start server in background with --patched flag
python3 simple_test_server.py $PORT --patched > server_patched.log 2>&1 &
SERVER_PID=$!

# Wait for server to start
sleep 2

# Check if server is running
if ! ps -p $SERVER_PID > /dev/null 2>&1; then
    echo "❌ Server failed to start"
    cat server_patched.log
    exit 1
fi

echo "✅ Server started (PID: $SERVER_PID)"
echo ""

# Run exploit
echo "Running exploit..."
echo ""
python3 exploit_poc.py localhost $PORT > exploit_patched.log 2>&1 || true

# Kill server
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

echo ""
echo "Server output:"
echo "--------------"
cat server_patched.log
echo ""
echo "Exploit output:"
echo "---------------"
cat exploit_patched.log
echo ""

echo "================================================================"
echo "  TEST COMPLETE"
echo "================================================================"
echo ""
echo "Logs saved:"
echo "  - server_unpatched.log"
echo "  - exploit_unpatched.log"
echo "  - server_patched.log"
echo "  - exploit_patched.log"
echo ""
