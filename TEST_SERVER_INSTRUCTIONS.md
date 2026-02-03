# TASK_6088 Test Server Instructions

This document explains how to build and run the test server for demonstrating the TASK_6088 vulnerability and patch.

---

## Overview

The test server provides a simple Thrift service with vulnerable data structures that can be exploited using `exploit_poc.py`.

**Files:**
- `test_server.thrift` - Service definition with vulnerable structures
- `test_server.cpp` - C++ server implementation
- `build_test_server.sh` - Build script (Linux/Mac)
- `build_test_server.bat` - Build script (Windows)

---

## Prerequisites

### Linux/Mac

```bash
# Install Apache Thrift
# Option 1: Package manager
sudo apt-get install thrift-compiler libthrift-dev  # Ubuntu/Debian
brew install thrift  # macOS

# Option 2: Build from source (to test patch)
cd /path/to/thrift/repository
./bootstrap.sh
./configure
make
sudo make install
```

### Windows

```powershell
# Install via vcpkg or build from source
# See: https://thrift.apache.org/docs/install/windows

# Or use WSL (recommended for testing)
wsl --install
# Then follow Linux instructions in WSL
```

---

## Building the Test Server

### Linux/Mac

```bash
# Make build script executable
chmod +x build_test_server.sh

# Build with current thrift compiler
./build_test_server.sh

# The script will:
# 1. Generate C++ code from test_server.thrift
# 2. Compile generated types
# 3. Compile server binary
# 4. Show security status (patched vs unpatched)
```

### Windows (WSL)

```bash
# Use WSL for easiest experience
wsl
cd /mnt/c/Users/scout/Desktop/Agent_Sprint/model_a
./build_test_server.sh
```

### Manual Build (All Platforms)

```bash
# Step 1: Generate code
thrift --gen cpp test_server.thrift

# Step 2: Compile generated code
g++ -std=c++11 -c gen-cpp/test_server_types.cpp -I/usr/include -I/usr/local/include -fPIC
g++ -std=c++11 -c gen-cpp/VulnerabilityTestService.cpp -I/usr/include -I/usr/local/include -fPIC

# Step 3: Compile server
g++ -std=c++11 -o test_server test_server.cpp \
    gen-cpp/test_server_types.o \
    gen-cpp/VulnerabilityTestService.o \
    -I/usr/include -I/usr/local/include \
    -lthrift -lpthread
```

---

## Running the Test

### Terminal 1: Start Server

```bash
./test_server 9090
```

**Expected Output:**
```
================================================================
  TASK_6088 Test Server
================================================================

Port: 9090

⚠️  WARNING: This server is for TESTING ONLY
   It may be vulnerable to resize bomb attacks.

To test:
  python3 exploit_poc.py localhost 9090

================================================================

[SERVER] Handler initialized
[SERVER] Starting server on port 9090...
[SERVER] Press Ctrl+C to stop
```

### Terminal 2: Run Exploit

```bash
python3 exploit_poc.py localhost 9090
```

---

## Expected Results

### Scenario 1: UNPATCHED Server

**Server Output:**
```
[SERVER] Processing structure...
terminate called after throwing an instance of 'std::bad_alloc'
  what():  std::bad_alloc
Aborted (core dumped)
```

**Exploit Output:**
```
[*] Connecting to localhost:9090...
[+] Connected!
[*] Sending 18 bytes...
[+] Payload sent!
[*] Waiting for response (timeout: 5s)...

⏱️  TIMEOUT: No response received
   This could indicate:
   - Unpatched server crashed (bad_alloc)
   - Server hung during allocation

⚠️  VULNERABLE: Service likely crashed or hung!
   This indicates the server is UNPATCHED.
   The service attempted to allocate 64 GB and failed.
```

**What happened:**
1. Exploit sent 18-byte payload claiming list has 2 billion elements
2. Server called `resize(2000000000)` without validation
3. Attempted to allocate 64 GB of memory
4. `std::bad_alloc` exception thrown
5. Server crashed

---

### Scenario 2: PATCHED Server

**Server Output:**
```
[SERVER] Processing structure...
[SERVER] Exception in processStructure: SIZE_LIMIT: List size exceeds maximum: 2000000000
```

**Exploit Output:**
```
[*] Connecting to localhost:9090...
[+] Connected!
[*] Sending 18 bytes...
[+] Payload sent!
[*] Waiting for response (timeout: 5s)...
[+] Received 47 bytes

✅ SUCCESS: Attack was BLOCKED!
   Server threw SIZE_LIMIT exception
   Service remains available

✅ PATCHED: Attack was successfully blocked!
   The SIZE_LIMIT exception indicates the patch is active.
   Service remained available and responsive.
```

**What happened:**
1. Exploit sent same 18-byte payload
2. Server validated size: `if (_size0 > 16777216) throw SIZE_LIMIT`
3. Exception thrown BEFORE resize()
4. No memory allocation attempted
5. Server continues running

---

## Checking Security Status

After building, examine the generated code:

```bash
# Check for SIZE_LIMIT protection
grep -n "SIZE_LIMIT" gen-cpp/test_server_types.cpp

# Check for resize() calls
grep -n "resize" gen-cpp/test_server_types.cpp
```

### Patched Output:
```
42:  if (_size0 > 16777216) {
43:    throw ::apache::thrift::protocol::TProtocolException(
44:      ::apache::thrift::protocol::TProtocolException::SIZE_LIMIT,
45:      "List size exceeds maximum: " + std::to_string(_size0));
46:  }
47:  this->dataItems.resize(_size0);
```

### Unpatched Output:
```
37:  this->dataItems.resize(_size0);  // No validation!
```

---

## Testing Different Attack Types

The exploit includes multiple attack vectors:

```bash
# Run all attacks
python3 exploit_poc.py localhost 9090

# The exploit will test:
# 1. List Resize Bomb (2 billion elements)
# 2. Map Iteration DoS (1 billion entries)
```

---

## Troubleshooting

### "thrift: command not found"

```bash
# Check if thrift is installed
which thrift

# If not found, install or add to PATH
export PATH=$PATH:/usr/local/bin

# Or build from source
cd /path/to/thrift
./bootstrap.sh && ./configure && make && sudo make install
```

### "undefined reference to `apache::thrift::...`"

```bash
# Install thrift development libraries
sudo apt-get install libthrift-dev  # Ubuntu
brew install thrift  # macOS

# Or check library path
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```

### "Connection refused"

```bash
# Check if server is running
netstat -tulpn | grep 9090

# Check if port is available
lsof -i :9090

# Try different port
./test_server 9091
python3 exploit_poc.py localhost 9091
```

### Server crashes immediately

```bash
# Check dependencies
ldd test_server

# Run with debug output
./test_server 9090 2>&1 | tee server.log
```

---

## Testing Workflow

### Full Test Cycle

1. **Build unpatched version:**
   ```bash
   # Use unpatched thrift compiler
   cd /path/to/thrift-unpatched
   make
   export PATH=$(pwd)/compiler/cpp:$PATH

   cd /path/to/model_a
   ./build_test_server.sh
   ```

2. **Test vulnerability:**
   ```bash
   # Terminal 1
   ./test_server 9090

   # Terminal 2
   python3 exploit_poc.py localhost 9090
   # Expected: Server crashes
   ```

3. **Apply patch:**
   ```bash
   cd /path/to/thrift
   git apply /path/to/model_a/TASK_6088_FINAL_PATCH.patch
   make clean
   make
   ```

4. **Build patched version:**
   ```bash
   cd /path/to/model_a
   ./build_test_server.sh
   ```

5. **Test protection:**
   ```bash
   # Terminal 1
   ./test_server 9090

   # Terminal 2
   python3 exploit_poc.py localhost 9090
   # Expected: Attack blocked, server continues
   ```

---

## Performance Testing

To verify the claimed <0.2% overhead:

```bash
# Create benchmark tool
cat > benchmark_client.py << 'EOF'
#!/usr/bin/env python3
import sys
import time
sys.path.append('gen-py')

from thrift.transport import TSocket, TTransport
from thrift.protocol import TBinaryProtocol
from task6088.test import VulnerabilityTestService
from task6088.test.ttypes import *

# Connect
transport = TSocket.TSocket('localhost', 9090)
transport = TTransport.TBufferedTransport(transport)
protocol = TBinaryProtocol.TBinaryProtocol(transport)
client = VulnerabilityTestService.Client(protocol)

transport.open()

# Benchmark
iterations = 10000
data = OuterStructure(
    timestamp=1234567890,
    containers=[
        MiddleContainer(containerId=i, dataItems=[
            InnerData(id=j, name=f"item_{j}")
            for j in range(100)
        ])
        for i in range(10)
    ]
)

start = time.time()
for i in range(iterations):
    result = client.processStructure(data)
end = time.time()

print(f"Processed {iterations} requests in {end-start:.2f}s")
print(f"Average: {(end-start)/iterations*1000:.2f}ms per request")

transport.close()
EOF

chmod +x benchmark_client.py
python3 benchmark_client.py
```

---

## Next Steps

After successful testing:

1. ✅ Verify exploit crashes unpatched server
2. ✅ Verify patch blocks exploit
3. ✅ Performance testing shows <0.2% overhead
4. Deploy patch to production (see TASK_6088_TURN_8_FINAL_HANDOFF.md)

---

## Security Notes

- **This test server is INTENTIONALLY VULNERABLE**
- Run only in isolated test environments
- Never expose to public networks
- Use firewall rules to restrict access
- Monitor resource usage during tests

---

## Support

For issues with:
- Thrift installation: https://thrift.apache.org/docs/install/
- Build errors: Check compiler/cpp/README.md in Thrift repo
- TASK_6088 specifics: See TASK_6088_SECURITY_RISK_ASSESSMENT.md
