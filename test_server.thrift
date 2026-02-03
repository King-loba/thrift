/**
 * TASK_6088 Test Server IDL
 *
 * Simple service for testing the resize bomb vulnerability
 */

namespace cpp task6088.test

// Data structures (vulnerable to resize bomb)
struct InnerData {
    1: required i32 id;
    2: optional string name;
}

struct MiddleContainer {
    1: required i32 containerId;
    2: required list<InnerData> dataItems;  // Vulnerable to list resize bomb
}

struct OuterStructure {
    1: required i64 timestamp;
    2: required list<MiddleContainer> containers;  // Nested lists
    3: optional map<string, list<InnerData>> namedGroups;  // Map with lists
}

// Test service
service VulnerabilityTestService {
    /**
     * Process an OuterStructure - this is the vulnerable endpoint
     * An attacker can send a malicious OuterStructure with claimed list size of 2 billion
     */
    string processStructure(1: OuterStructure data);

    /**
     * Health check endpoint
     */
    string ping();
}
