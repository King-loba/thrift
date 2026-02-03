/**
 * TASK_6088 Test Server Implementation
 *
 * Simple server for testing resize bomb vulnerability
 *
 * Build:
 *   g++ -std=c++11 -o test_server test_server.cpp \
 *       gen-cpp/VulnerabilityTestService.cpp \
 *       gen-cpp/test_server_types.cpp \
 *       -I/usr/include -I/usr/local/include \
 *       -lthrift -lpthread
 *
 * Run:
 *   ./test_server [port]
 *
 * Default port: 9090
 */

#include <iostream>
#include <memory>
#include <string>

#include <thrift/protocol/TBinaryProtocol.h>
#include <thrift/server/TSimpleServer.h>
#include <thrift/transport/TServerSocket.h>
#include <thrift/transport/TBufferTransports.h>

#include "gen-cpp/VulnerabilityTestService.h"

using namespace ::apache::thrift;
using namespace ::apache::thrift::protocol;
using namespace ::apache::thrift::transport;
using namespace ::apache::thrift::server;

using namespace ::task6088::test;

/**
 * Implementation of the test service
 */
class VulnerabilityTestServiceHandler : virtual public VulnerabilityTestServiceIf {
public:
    VulnerabilityTestServiceHandler() {
        std::cout << "[SERVER] Handler initialized" << std::endl;
    }

    /**
     * Process structure - this is where the vulnerability will trigger
     */
    void processStructure(std::string& _return, const OuterStructure& data) {
        std::cout << "[SERVER] Processing structure..." << std::endl;
        std::cout << "[SERVER]   Timestamp: " << data.timestamp << std::endl;
        std::cout << "[SERVER]   Containers: " << data.containers.size() << std::endl;

        // If we get here, the structure was successfully deserialized
        std::cout << "[SERVER] ✅ Structure processed successfully!" << std::endl;

        _return = "SUCCESS: Structure processed";
    }

    /**
     * Health check
     */
    void ping(std::string& _return) {
        std::cout << "[SERVER] Ping received" << std::endl;
        _return = "PONG";
    }
};

int main(int argc, char **argv) {
    // Parse port
    int port = 9090;
    if (argc > 1) {
        port = std::atoi(argv[1]);
    }

    std::cout << "================================================================" << std::endl;
    std::cout << "  TASK_6088 Test Server" << std::endl;
    std::cout << "================================================================" << std::endl;
    std::cout << std::endl;
    std::cout << "Port: " << port << std::endl;
    std::cout << std::endl;
    std::cout << "⚠️  WARNING: This server is for TESTING ONLY" << std::endl;
    std::cout << "   It may be vulnerable to resize bomb attacks." << std::endl;
    std::cout << std::endl;
    std::cout << "To test:" << std::endl;
    std::cout << "  python3 exploit_poc.py localhost " << port << std::endl;
    std::cout << std::endl;
    std::cout << "================================================================" << std::endl;
    std::cout << std::endl;

    try {
        // Create handler
        std::shared_ptr<VulnerabilityTestServiceHandler> handler(
            new VulnerabilityTestServiceHandler()
        );

        // Create processor
        std::shared_ptr<TProcessor> processor(
            new VulnerabilityTestServiceProcessor(handler)
        );

        // Create server socket
        std::shared_ptr<TServerTransport> serverTransport(
            new TServerSocket(port)
        );

        // Create transport factory
        std::shared_ptr<TTransportFactory> transportFactory(
            new TBufferedTransportFactory()
        );

        // Create protocol factory
        std::shared_ptr<TProtocolFactory> protocolFactory(
            new TBinaryProtocolFactory()
        );

        // Create server
        TSimpleServer server(
            processor,
            serverTransport,
            transportFactory,
            protocolFactory
        );

        std::cout << "[SERVER] Starting server on port " << port << "..." << std::endl;
        std::cout << "[SERVER] Press Ctrl+C to stop" << std::endl;
        std::cout << std::endl;

        // Serve
        server.serve();

    } catch (const std::exception& e) {
        std::cerr << "[SERVER] ❌ ERROR: " << e.what() << std::endl;
        return 1;
    }

    std::cout << "[SERVER] Server stopped" << std::endl;
    return 0;
}
