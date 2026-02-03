#!/usr/bin/env python3
"""
TASK_6088 Simple Test Server

This Python server simulates the vulnerable behavior for testing purposes.
It demonstrates what happens when a malicious payload is received.

Usage:
    python3 simple_test_server.py [port] [--patched]

Arguments:
    port      - Port to listen on (default: 9090)
    --patched - Simulate patched behavior (apply SIZE_LIMIT checks)
"""

import socket
import struct
import sys
from io import BytesIO

# Thrift type constants
class TType:
    STOP   = 0
    I64    = 10
    LIST   = 15
    STRUCT = 12

# Configuration
MAX_CONTAINER_SIZE = 16 * 1024 * 1024  # 16M elements (from patch)


class ThriftProtocolReader:
    """Simulates Thrift TBinaryProtocol deserialization"""

    def __init__(self, data, patched=False):
        self.buffer = BytesIO(data)
        self.patched = patched
        self.bytes_read = 0

    def read_byte(self):
        """Read a single byte"""
        data = self.buffer.read(1)
        if len(data) != 1:
            raise EOFError("Unexpected end of data")
        self.bytes_read += 1
        return struct.unpack('!b', data)[0]

    def read_i16(self):
        """Read 16-bit integer"""
        data = self.buffer.read(2)
        if len(data) != 2:
            raise EOFError("Unexpected end of data")
        self.bytes_read += 2
        return struct.unpack('!h', data)[0]

    def read_i32(self):
        """Read 32-bit integer"""
        data = self.buffer.read(4)
        if len(data) != 4:
            raise EOFError("Unexpected end of data")
        self.bytes_read += 4
        return struct.unpack('!i', data)[0]

    def read_i64(self):
        """Read 64-bit integer"""
        data = self.buffer.read(8)
        if len(data) != 8:
            raise EOFError("Unexpected end of data")
        self.bytes_read += 8
        return struct.unpack('!q', data)[0]

    def read_struct(self, depth=0):
        """Read a Thrift struct (simulated)"""
        indent = "  " * depth
        print(f"{indent}[DESERIALIZE] Reading struct at depth {depth}...")

        field_count = 0
        while True:
            # Read field type
            field_type = self.read_byte()

            if field_type == TType.STOP:
                print(f"{indent}[DESERIALIZE] Struct end (STOP marker)")
                break

            # Read field ID
            field_id = self.read_i16()
            field_count += 1

            print(f"{indent}[DESERIALIZE] Field {field_id}, type={field_type}")

            # Read field value based on type
            if field_type == TType.I64:
                value = self.read_i64()
                print(f"{indent}  → Value: {value}")

            elif field_type == TType.LIST:
                self.read_list(depth + 1)

            else:
                print(f"{indent}  → Unknown type {field_type}")

        print(f"{indent}[DESERIALIZE] Struct complete ({field_count} fields)")

    def read_list(self, depth=0):
        """Read a Thrift list - THIS IS WHERE THE VULNERABILITY IS"""
        indent = "  " * depth
        print(f"{indent}[DESERIALIZE] Reading list...")

        # Read element type
        elem_type = self.read_byte()
        print(f"{indent}  Element type: {elem_type}")

        # Read list size - THE CRITICAL VALUE
        list_size = self.read_i32()
        print(f"{indent}  Claimed size: {list_size:,} elements")

        # Calculate memory requirements
        struct_size = 32  # Approximate size of a struct in bytes
        total_memory = list_size * struct_size
        total_gb = total_memory / (1024 ** 3)

        print(f"{indent}  Memory needed: {total_memory:,} bytes ({total_gb:.2f} GB)")

        # ═══════════════════════════════════════════════════════════
        # VULNERABILITY CHECK POINT
        # ═══════════════════════════════════════════════════════════

        if self.patched:
            # PATCHED BEHAVIOR: Validate before allocation
            print(f"{indent}[SECURITY] Checking size against limit...")

            if list_size > MAX_CONTAINER_SIZE:
                error_msg = f"List size exceeds maximum: {list_size}"
                print(f"{indent}[SECURITY] ❌ SIZE_LIMIT EXCEPTION!")
                print(f"{indent}            {error_msg}")
                raise Exception(f"SIZE_LIMIT: {error_msg}")

            print(f"{indent}[SECURITY] ✅ Size OK ({list_size:,} <= {MAX_CONTAINER_SIZE:,})")

        else:
            # UNPATCHED BEHAVIOR: No validation - just try to allocate
            print(f"{indent}[VULNERABLE] No size validation!")
            print(f"{indent}[VULNERABLE] Attempting: resize({list_size:,})")

            if total_gb > 1.0:  # More than 1 GB
                print(f"{indent}[SYSTEM] ⚠️  Allocating {total_gb:.2f} GB...")
                print(f"{indent}[SYSTEM] ❌ std::bad_alloc exception!")
                print(f"{indent}[SYSTEM] 💥 SERVER CRASH!")
                raise MemoryError(f"std::bad_alloc: Cannot allocate {total_memory:,} bytes")

        # If we get here, allocation succeeded
        print(f"{indent}[DESERIALIZE] List allocated successfully")
        print(f"{indent}[DESERIALIZE] Reading {list_size} elements...")

        # Try to read elements (will fail if no data sent)
        for i in range(min(list_size, 10)):  # Only try first 10
            print(f"{indent}  Element {i}...")
            if elem_type == TType.STRUCT:
                self.read_struct(depth + 1)


class SimpleTestServer:
    """Simple test server for demonstrating the vulnerability"""

    def __init__(self, port=9090, patched=False):
        self.port = port
        self.patched = patched

    def print_banner(self):
        """Print server banner"""
        print("=" * 70)
        print("  TASK_6088 Simple Test Server")
        print("=" * 70)
        print()
        print(f"Port:   {self.port}")
        print(f"Mode:   {'PATCHED (SIZE_LIMIT enabled)' if self.patched else 'UNPATCHED (Vulnerable)'}")
        print()
        if self.patched:
            print("✅ Security: SIZE_LIMIT checks ENABLED")
            print(f"   Maximum container size: {MAX_CONTAINER_SIZE:,} elements")
        else:
            print("⚠️  Security: SIZE_LIMIT checks DISABLED")
            print("   This server is VULNERABLE to resize bomb attacks!")
        print()
        print("=" * 70)
        print()

    def handle_connection(self, conn, addr):
        """Handle incoming connection"""
        print(f"\n[SERVER] Connection from {addr[0]}:{addr[1]}")

        try:
            # Receive data
            data = conn.recv(4096)
            print(f"[SERVER] Received {len(data)} bytes")

            if len(data) == 0:
                print("[SERVER] No data received")
                return

            # Show hex dump
            print(f"[SERVER] Payload hex dump:")
            hex_str = " ".join(f"{b:02x}" for b in data[:64])
            print(f"          {hex_str}")
            if len(data) > 64:
                print(f"          ... ({len(data) - 64} more bytes)")
            print()

            # Try to deserialize
            print("[SERVER] Starting deserialization...")
            print("-" * 70)

            try:
                reader = ThriftProtocolReader(data, patched=self.patched)
                reader.read_struct()

                # Success
                print("-" * 70)
                print("[SERVER] ✅ Deserialization successful!")

                # Send success response
                response = b"SUCCESS"
                conn.sendall(response)
                print(f"[SERVER] Sent response: {response.decode()}")

            except Exception as e:
                # Deserialization failed
                print("-" * 70)

                if "SIZE_LIMIT" in str(e):
                    # Patch blocked the attack
                    print("[SERVER] 🛡️  ATTACK BLOCKED BY PATCH")
                    print(f"[SERVER]    Exception: {e}")
                    print("[SERVER]    Server continues running...")

                    # Send error response (what Thrift would do)
                    response = b"SIZE_LIMIT: " + str(e).encode()
                    conn.sendall(response)
                    print(f"[SERVER] Sent SIZE_LIMIT exception to client")

                elif isinstance(e, MemoryError):
                    # Simulated crash
                    print("[SERVER] 💥 CRASH SIMULATED")
                    print(f"[SERVER]    {e}")
                    print("[SERVER]    In real C++ server: process would terminate")
                    print("[SERVER]    Connection dropped, no response sent")
                    # Don't send response - simulate crash

                else:
                    print(f"[SERVER] ❌ Error: {e}")
                    raise

        except Exception as e:
            print(f"[SERVER] Fatal error: {e}")
            import traceback
            traceback.print_exc()

        finally:
            conn.close()
            print(f"[SERVER] Connection closed")

    def run(self):
        """Run the server"""
        self.print_banner()

        # Create socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        try:
            sock.bind(('0.0.0.0', self.port))
            sock.listen(5)

            print(f"[SERVER] Listening on port {self.port}...")
            print(f"[SERVER] Press Ctrl+C to stop")
            print()
            print("To test, run in another terminal:")
            print(f"  python3 exploit_poc.py localhost {self.port}")
            print()

            while True:
                conn, addr = sock.accept()
                self.handle_connection(conn, addr)

        except KeyboardInterrupt:
            print("\n\n[SERVER] Interrupted by user")

        finally:
            sock.close()
            print("[SERVER] Server stopped")


def main():
    """Main entry point"""
    # Parse arguments
    port = 9090
    patched = False

    for arg in sys.argv[1:]:
        if arg in ['--patched', '-p']:
            patched = True
        elif arg in ['--help', '-h']:
            print(__doc__)
            sys.exit(0)
        else:
            try:
                port = int(arg)
            except ValueError:
                print(f"Error: Invalid port '{arg}'")
                sys.exit(1)

    # Create and run server
    server = SimpleTestServer(port=port, patched=patched)
    server.run()


if __name__ == '__main__':
    main()
