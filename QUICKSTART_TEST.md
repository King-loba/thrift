# TASK_6088 Vulnerability Test - Quick Start

**Goal:** Demonstrate the resize bomb vulnerability and verify the patch works.

---

## TL;DR - Fast Track

```bash
# Using WSL on Windows (recommended)
wsl

# Navigate to project
cd /mnt/c/Users/scout/Desktop/Agent_Sprint/model_a

# Build test server
chmod +x build_test_server.sh
./build_test_server.sh

# Terminal 1: Start server
./test_server 9090

# Terminal 2: Run exploit
python3 exploit_poc.py localhost 9090

# Observe: Unpatched crashes, Patched blocks attack
```

---

## Step-by-Step (First Time)

### 1. Install Apache Thrift (One Time Setup)

#### On Ubuntu/Debian (WSL)
```bash
sudo apt-get update
sudo apt-get install -y \
    automake \
    bison \
    flex \
    g++ \
    git \
    libboost-all-dev \
    libevent-dev \
    libssl-dev \
    libtool \
    make \
    pkg-config

# Clone Thrift repo
cd ~
git clone https://github.com/apache/thrift.git
cd thrift

# Build
./bootstrap.sh
./configure --without-python --without-java --without-go
make -j$(nproc)
sudo make install
sudo ldconfig

# Verify
thrift -version
# Expected: Thrift version 0.x.x
```

#### On macOS
```bash
brew install thrift

# Verify
thrift -version
```

### 2. Build Test Server

```bash
# Navigate to project
cd /mnt/c/Users/scout/Desktop/Agent_Sprint/model_a  # WSL
# or
cd ~/Desktop/Agent_Sprint/model_a  # macOS/Linux

# Make build script executable
chmod +x build_test_server.sh

# Build
./build_test_server.sh
```

**Expected Output:**
```
================================================================
  TASK_6088 Test Server Build
================================================================

[1/4] Cleaning old generated code...
[2/4] Generating C++ code from test_server.thrift...
[3/4] Compiling generated Thrift types...
[4/4] Compiling test server...

================================================================
✅ BUILD SUCCESSFUL
================================================================

Server binary: ./test_server
Binary size:   XXX KB

Security Status:
  ⚠️  UNPATCHED - No SIZE_LIMIT checks found
     The exploit may cause a CRASH
```

### 3. Test Vulnerability (Unpatched)

**Terminal 1:**
```bash
./test_server 9090
```

**Terminal 2:**
```bash
python3 exploit_poc.py localhost 9090
```

**Expected Result:**
- **Terminal 1:** Server crashes with `std::bad_alloc`
- **Terminal 2:** Timeout, message says "VULNERABLE"

### 4. Apply Patch

```bash
# Navigate to Thrift source
cd ~/thrift

# Apply TASK_6088 patch
git apply /mnt/c/Users/scout/Desktop/Agent_Sprint/model_a/TASK_6088_FINAL_PATCH.patch

# Rebuild Thrift
make clean
make -j$(nproc)
sudo make install
sudo ldconfig
```

### 5. Rebuild Test Server (Patched)

```bash
# Navigate back to project
cd /mnt/c/Users/scout/Desktop/Agent_Sprint/model_a

# Rebuild
./build_test_server.sh
```

**Expected Output:**
```
Security Status:
  ✅ PATCHED - SIZE_LIMIT checks found in generated code
     The exploit should be BLOCKED
```

### 6. Test Protection (Patched)

**Terminal 1:**
```bash
./test_server 9090
```

**Terminal 2:**
```bash
python3 exploit_poc.py localhost 9090
```

**Expected Result:**
- **Terminal 1:** Server logs exception but CONTINUES RUNNING
- **Terminal 2:** "SUCCESS: Attack was BLOCKED!"

---

## What You'll See

### Unpatched Server

```
================================================================
  TASK_6088 - Proof of Concept: List Resize Bomb
================================================================

Attack Type:        List Resize Bomb
Payload Size:       18 bytes
Claimed List Size:  2,000,000,000 elements
Expected Alloc:     64,000,000,000 bytes (59.6 GB)
Amplification:      3,555,555,556x

[*] Connecting to localhost:9090...
[+] Connected!
[*] Sending 18 bytes...
[+] Payload sent!
[*] Waiting for response (timeout: 5s)...

⏱️  TIMEOUT: No response received
   This could indicate:
   - Unpatched server crashed (bad_alloc)
   - Server hung during allocation

──────────────────────────────────────────────────────────────
⚠️  VULNERABLE: Service likely crashed or hung!
   This indicates the server is UNPATCHED.
   The service attempted to allocate 64 GB and failed.
──────────────────────────────────────────────────────────────
```

### Patched Server

```
================================================================
  TASK_6088 - Proof of Concept: List Resize Bomb
================================================================

Attack Type:        List Resize Bomb
Payload Size:       18 bytes
Claimed List Size:  2,000,000,000 elements
Expected Alloc:     64,000,000,000 bytes (59.6 GB)
Amplification:      3,555,555,556x

[*] Connecting to localhost:9090...
[+] Connected!
[*] Sending 18 bytes...
[+] Payload sent!
[*] Waiting for response (timeout: 5s)...
[+] Received 47 bytes

✅ SUCCESS: Attack was BLOCKED!
   Server threw SIZE_LIMIT exception
   Service remains available

──────────────────────────────────────────────────────────────
✅ PATCHED: Attack was successfully blocked!
   The SIZE_LIMIT exception indicates the patch is active.
   Service remained available and responsive.
──────────────────────────────────────────────────────────────
```

---

## Examining the Generated Code

### Check for Vulnerability

```bash
# Look at the deserialization code
less gen-cpp/test_server_types.cpp

# Search for resize() calls
/resize

# In UNPATCHED version, you'll see:
#   this->dataItems.resize(_size0);  // No validation!

# In PATCHED version, you'll see:
#   if (_size0 > 16777216) {
#     throw SIZE_LIMIT;
#   }
#   this->dataItems.resize(_size0);  // Safe!
```

### View All Security Checks

```bash
# Find all SIZE_LIMIT checks
grep -n "SIZE_LIMIT" gen-cpp/test_server_types.cpp

# Expected in patched version:
# Line XX: if (_size0 > 16777216) { throw SIZE_LIMIT; }
# Line YY: if (_i > 16777216) { throw SIZE_LIMIT; }
# (Multiple checks for nested containers)
```

---

## Troubleshooting

### "Connection refused"
```bash
# Check if server is running
ps aux | grep test_server

# Check port
netstat -tulpn | grep 9090
```

### "thrift: command not found"
```bash
# Add to PATH
export PATH=$PATH:/usr/local/bin

# Or specify full path in build script
which thrift
```

### Server builds but crashes on startup
```bash
# Check dependencies
ldd ./test_server

# Check for missing libraries
sudo apt-get install libthrift-0.x.0

# Or set library path
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```

---

## Cleanup

```bash
# Stop server
pkill test_server

# Clean build artifacts
rm -rf gen-cpp test_server *.o
```

---

## Next Steps After Testing

1. ✅ Confirmed vulnerability exists (unpatched crashes)
2. ✅ Confirmed patch works (patched blocks attack)
3. Document results in test report
4. Deploy patch to production (see TASK_6088_TURN_8_FINAL_HANDOFF.md)
5. Monitor production for SIZE_LIMIT exceptions (indicates attack attempts)

---

## Files Created

- `test_server.thrift` - Service definition with vulnerable structures
- `test_server.cpp` - Server implementation
- `build_test_server.sh` - Build script (Linux/Mac)
- `build_test_server.bat` - Build script (Windows)
- `TEST_SERVER_INSTRUCTIONS.md` - Detailed instructions
- `QUICKSTART_TEST.md` - This file

---

## Support

**For build issues:** See TEST_SERVER_INSTRUCTIONS.md

**For exploit details:** See TASK_6088_POC_VERIFICATION.md

**For patch details:** See TASK_6088_SECURITY_RISK_ASSESSMENT.md
