const std = @import("std");
pub const csr = @import("csr.zig");

test "Include other unit tests" {
    std.testing.refAllDecls(csr);
}

/// Storage interface that graph storage implementations must satisfy
pub fn StorageInterface(comptime NodeType: type, comptime EdgeType: type) type {
    _ = NodeType;
    _ = EdgeType;
    return struct {
        pub const NodeIndex = u32;
        pub const EdgeIndex = usize;
        
        // Required methods for any storage implementation:
        // - init(allocator) -> Self
        // - deinit(self: *Self) -> void
        // - addNode(self: *Self, weight: NodeType) -> !NodeIndex
        // - addEdge(self: *Self, source: NodeIndex, target: NodeIndex, weight: EdgeType) -> !bool
        // - containsEdge(self: *Self, source: NodeIndex, target: NodeIndex) -> bool
        // - nodeCount(self: *Self) -> usize
        // - edgeCount(self: *Self) -> usize
        // - getNodeWeight(self: *Self, node: NodeIndex) -> NodeType
        // - setNodeWeight(self: *Self, node: NodeIndex, weight: NodeType) -> void
    };
}

/// CSR-based storage implementation
pub fn CsrStorage(comptime NodeType: type, comptime EdgeType: type) type {
    return struct {
        const Self = @This();
        const CsrImpl = csr.Csr(NodeType, EdgeType);
        
        pub const NodeIndex = u32;
        pub const EdgeIndex = usize;
        
        csr_graph: CsrImpl,
        
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .csr_graph = CsrImpl.init(allocator),
            };
        }
        
        pub fn deinit(self: *Self) void {
            self.csr_graph.deinit();
        }
        
        pub fn addNode(self: *Self, weight: NodeType) !NodeIndex {
            return self.csr_graph.addNode(weight);
        }
        
        pub fn addEdge(self: *Self, source: NodeIndex, target: NodeIndex, weight: EdgeType) !bool {
            return self.csr_graph.addEdge(source, target, weight);
        }
        
        pub fn containsEdge(self: *Self, source: NodeIndex, target: NodeIndex) bool {
            return self.csr_graph.containsEdge(source, target);
        }
        
        pub fn nodeCount(self: *Self) usize {
            return self.csr_graph.nodeCount();
        }
        
        pub fn edgeCount(self: *Self) usize {
            return self.csr_graph.edgeCount();
        }
        
        pub fn getNodeWeight(self: *Self, node: NodeIndex) NodeType {
            return self.csr_graph.getNodeWeight(node);
        }
        
        pub fn setNodeWeight(self: *Self, node: NodeIndex, weight: NodeType) void {
            self.csr_graph.setNodeWeight(node, weight);
        }
        
        // CSR-specific methods
        pub fn neighborsSlice(self: *Self, node: NodeIndex) []const NodeIndex {
            return self.csr_graph.neighborsSlice(node);
        }
        
        pub fn edgesSlice(self: *Self, node: NodeIndex) []const EdgeType {
            return self.csr_graph.edgesSlice(node);
        }
        
        pub fn outDegree(self: *Self, node: NodeIndex) usize {
            return self.csr_graph.outDegree(node);
        }
    };
}

pub fn Graph(comptime NodeType: type, comptime EdgeType: type, comptime StorageType: ?type) type {
    const ActualStorage = if (StorageType) |S| S else CsrStorage(NodeType, EdgeType);
    
    return struct {
        const Self = @This();
        pub const Node = NodeType;
        pub const Edge = EdgeType;
        pub const Storage = ActualStorage;
        pub const NodeIndex = ActualStorage.NodeIndex;
        pub const EdgeIndex = ActualStorage.EdgeIndex;

        storage: Storage,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .storage = Storage.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.storage.deinit();
        }
        
        pub fn addNode(self: *Self, weight: NodeType) !NodeIndex {
            return self.storage.addNode(weight);
        }
        
        pub fn addEdge(self: *Self, source: NodeIndex, target: NodeIndex, weight: EdgeType) !bool {
            return self.storage.addEdge(source, target, weight);
        }
        
        pub fn containsEdge(self: *Self, source: NodeIndex, target: NodeIndex) bool {
            return self.storage.containsEdge(source, target);
        }
        
        pub fn nodeCount(self: *Self) usize {
            return self.storage.nodeCount();
        }
        
        pub fn edgeCount(self: *Self) usize {
            return self.storage.edgeCount();
        }
        
        pub fn getNodeWeight(self: *Self, node: NodeIndex) NodeType {
            return self.storage.getNodeWeight(node);
        }
        
        pub fn setNodeWeight(self: *Self, node: NodeIndex, weight: NodeType) void {
            self.storage.setNodeWeight(node, weight);
        }
    };
}

