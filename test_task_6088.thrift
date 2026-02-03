/**
 * Test file for TASK_6088: Investigating nested T_STRUCT and T_LIST handling
 * This file tests deep nesting to identify potential issues with:
 * - Variable shadowing in nested loops
 * - Protocol state management
 * - Memory allocation during deserialization
 */

namespace cpp test.task6088

// Inner-most struct
struct InnerData {
  1: required i32 id;
  2: optional string name;
  3: optional double value;
}

// Middle-level struct containing a list of InnerData
struct MiddleContainer {
  1: required i32 containerId;
  2: required list<InnerData> dataItems;
  3: optional string description;
}

// Outer-most struct containing a list of MiddleContainers
struct OuterStructure {
  1: required i64 timestamp;
  2: required list<MiddleContainer> containers;
  3: optional map<string, list<InnerData>> namedGroups;
}

// Even more complex: nested lists within lists
struct DeepNesting {
  1: required i32 depth;
  2: required list<list<InnerData>> nestedLists;
  3: optional list<MiddleContainer> mixedContainers;
}

// Service to test these structures
service TestService {
  OuterStructure processData(1: OuterStructure input);
  DeepNesting processDeepNesting(1: DeepNesting input);
}
