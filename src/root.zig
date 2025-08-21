const std = @import("std");
pub const csr = @import("csr.zig");
pub const dijkstra = @import("dijkstra.zig");
pub const traversal = @import("traversal.zig");
pub const topology = @import("topology.zig");
pub const storage = @import("storage.zig");

// Re-export Dijkstra types and functions for public API compatibility
pub const DijkstraResult = dijkstra.DijkstraResult;

// Re-export storage types for public API
pub const StorageInterface = storage.StorageInterface;
pub const CsrStorage = storage.CsrStorage;
pub const MatrixStorage = storage.MatrixStorage;
pub const Graph = @import("graph.zig").Graph;

test "Include other unit tests" {
    std.testing.refAllDecls(csr);
    std.testing.refAllDecls(dijkstra);
    std.testing.refAllDecls(traversal);
    std.testing.refAllDecls(topology);
    std.testing.refAllDecls(storage);
}

test "Graph neighbor access and iteration" {
    const allocator = std.testing.allocator;

    var graph = Graph(u32, f32, null).init(allocator);
    defer graph.deinit();

    // Add nodes
    const a = try graph.addNode(1);
    const b = try graph.addNode(2);
    const c = try graph.addNode(3);

    // Add edges
    _ = try graph.addEdge(a, b, 1.5);
    _ = try graph.addEdge(a, c, 2.0);

    // Test neighbors access
    const neighbors = graph.neighbors(a);
    try std.testing.expect(neighbors.len == 2);
    try std.testing.expect(neighbors[0] == b);
    try std.testing.expect(neighbors[1] == c);

    // Test neighbor iteration
    var iter = graph.neighborIterator(a);
    var count: usize = 0;
    while (iter.next()) |item| {
        count += 1;
        if (item.neighbor == b) {
            try std.testing.expect(item.edge == 1.5);
        } else if (item.neighbor == c) {
            try std.testing.expect(item.edge == 2.0);
        }
    }
    try std.testing.expect(count == 2);

    // Test out-degree
    try std.testing.expect(graph.outDegree(a) == 2);
    try std.testing.expect(graph.outDegree(b) == 0);
}

test "Graph BFS traversal" {
    const allocator = std.testing.allocator;

    var graph = Graph(void, void, null).init(allocator);
    defer graph.deinit();

    // Create a simple graph: 0->1, 0->2, 1->3
    const a = try graph.addNode({});
    const b = try graph.addNode({});
    const c = try graph.addNode({});
    const d = try graph.addNode({});

    _ = try graph.addEdge(a, b, {});
    _ = try graph.addEdge(a, c, {});
    _ = try graph.addEdge(b, d, {});

    // Test BFS order
    var visited = std.ArrayListUnmanaged(u32).empty;
    defer visited.deinit(allocator);

    const TestVisitor = struct {
        fn visit(node: u32) void {
            // This is a simplified test - in practice you'd capture the list somehow
            _ = node; // Just mark as used for now
        }
    };

    // For testing, we'll just verify BFS doesn't crash and completes
    try graph.bfs(allocator, a, TestVisitor.visit);
}

test "Graph DFS traversal" {
    const allocator = std.testing.allocator;

    var graph = Graph(void, void, null).init(allocator);
    defer graph.deinit();

    // Create a simple linear graph: 0->1->2
    const a = try graph.addNode({});
    const b = try graph.addNode({});
    const c = try graph.addNode({});

    _ = try graph.addEdge(a, b, {});
    _ = try graph.addEdge(b, c, {});

    // Test DFS order
    const TestVisitor = struct {
        fn visit(node: u32) void {
            // This is a simplified test - in practice you'd capture the list somehow
            _ = node; // Just mark as used for now
        }
    };

    // For testing, we'll just verify DFS doesn't crash and completes
    try graph.dfs(allocator, a, TestVisitor.visit);
}

test "Dijkstra shortest path with numeric weights" {
    const allocator = std.testing.allocator;

    var graph = Graph(void, u32, null).init(allocator);
    defer graph.deinit();

    // Create a diamond graph with different path costs
    const a = try graph.addNode({});
    const b = try graph.addNode({});
    const c = try graph.addNode({});
    const d = try graph.addNode({});

    _ = try graph.addEdge(a, b, 1); // Short path: a->b->d (cost 4)
    _ = try graph.addEdge(a, c, 10); // Long path: a->c->d (cost 11)
    _ = try graph.addEdge(b, d, 3);
    _ = try graph.addEdge(c, d, 1);

    // Run Dijkstra from node a
    var result = (try graph.dijkstra(allocator, a)) orelse {
        try std.testing.expect(false); // Should not be null
        return;
    };
    defer result.deinit();

    // Check distances
    try std.testing.expect(result.distanceTo(a).? == 0);
    try std.testing.expect(result.distanceTo(b).? == 1);
    try std.testing.expect(result.distanceTo(c).? == 10);
    try std.testing.expect(result.distanceTo(d).? == 4); // Should take shorter path through b

    // Check reachability
    try std.testing.expect(result.isReachable(a));
    try std.testing.expect(result.isReachable(b));
    try std.testing.expect(result.isReachable(c));
    try std.testing.expect(result.isReachable(d));

    // Check shortest path to d
    const path = (try result.pathTo(allocator, d)) orelse {
        try std.testing.expect(false); // Should not be null
        return;
    };
    defer allocator.free(path);

    try std.testing.expect(path.len == 3);
    try std.testing.expect(path[0] == a);
    try std.testing.expect(path[1] == b);
    try std.testing.expect(path[2] == d);
}

test "Topological sort - empty graph" {
    const allocator = std.testing.allocator;

    var graph = Graph(void, void, null).init(allocator);
    defer graph.deinit();

    var result = try graph.topologicalSort(allocator);
    defer result.deinit();

    try std.testing.expect(result.order.len == 0);
    try std.testing.expect(!result.has_cycles);
}

test "Topological sort - single node" {
    const allocator = std.testing.allocator;

    var graph = Graph(void, void, null).init(allocator);
    defer graph.deinit();

    const a = try graph.addNode({});

    var result = try graph.topologicalSort(allocator);
    defer result.deinit();

    try std.testing.expect(result.order.len == 1);
    try std.testing.expect(result.order[0] == a);
    try std.testing.expect(!result.has_cycles);
}

test "Topological sort - simple DAG" {
    const allocator = std.testing.allocator;

    var graph = Graph(void, void, null).init(allocator);
    defer graph.deinit();

    // Create a simple DAG: A -> B -> C
    const a = try graph.addNode({});
    const b = try graph.addNode({});
    const c = try graph.addNode({});

    _ = try graph.addEdge(a, b, {});
    _ = try graph.addEdge(b, c, {});

    var result = try graph.topologicalSort(allocator);
    defer result.deinit();

    try std.testing.expect(result.order.len == 3);
    try std.testing.expect(!result.has_cycles);

    // Check that A comes before B, and B comes before C
    var a_pos: usize = undefined;
    var b_pos: usize = undefined;
    var c_pos: usize = undefined;

    for (result.order, 0..) |node, i| {
        if (node == a) a_pos = i;
        if (node == b) b_pos = i;
        if (node == c) c_pos = i;
    }

    try std.testing.expect(a_pos < b_pos);
    try std.testing.expect(b_pos < c_pos);
}

test "Topological sort - complex DAG" {
    const allocator = std.testing.allocator;

    var graph = Graph(void, void, null).init(allocator);
    defer graph.deinit();

    // Create a diamond DAG: A -> B, A -> C, B -> D, C -> D
    const a = try graph.addNode({});
    const b = try graph.addNode({});
    const c = try graph.addNode({});
    const d = try graph.addNode({});

    _ = try graph.addEdge(a, b, {});
    _ = try graph.addEdge(a, c, {});
    _ = try graph.addEdge(b, d, {});
    _ = try graph.addEdge(c, d, {});

    var result = try graph.topologicalSort(allocator);
    defer result.deinit();

    try std.testing.expect(result.order.len == 4);
    try std.testing.expect(!result.has_cycles);

    // Check that A comes first, D comes last, and B,C come before D
    var a_pos: usize = undefined;
    var b_pos: usize = undefined;
    var c_pos: usize = undefined;
    var d_pos: usize = undefined;

    for (result.order, 0..) |node, i| {
        if (node == a) a_pos = i;
        if (node == b) b_pos = i;
        if (node == c) c_pos = i;
        if (node == d) d_pos = i;
    }

    try std.testing.expect(a_pos == 0); // A should be first
    try std.testing.expect(d_pos == 3); // D should be last
    try std.testing.expect(a_pos < b_pos);
    try std.testing.expect(a_pos < c_pos);
    try std.testing.expect(b_pos < d_pos);
    try std.testing.expect(c_pos < d_pos);
}

test "Topological sort - cyclic graph" {
    const allocator = std.testing.allocator;

    var graph = Graph(void, void, null).init(allocator);
    defer graph.deinit();

    // Create a cycle: A -> B -> C -> A
    const a = try graph.addNode({});
    const b = try graph.addNode({});
    const c = try graph.addNode({});

    _ = try graph.addEdge(a, b, {});
    _ = try graph.addEdge(b, c, {});
    _ = try graph.addEdge(c, a, {}); // This creates a cycle

    var result = try graph.topologicalSort(allocator);
    defer result.deinit();

    try std.testing.expect(result.has_cycles);
    try std.testing.expect(result.order.len < 3); // Should not include all nodes
}

test "Topological sort - disconnected components" {
    const allocator = std.testing.allocator;

    var graph = Graph(void, void, null).init(allocator);
    defer graph.deinit();

    // Create two disconnected components: A -> B and C -> D
    const a = try graph.addNode({});
    const b = try graph.addNode({});
    const c = try graph.addNode({});
    const d = try graph.addNode({});

    _ = try graph.addEdge(a, b, {});
    _ = try graph.addEdge(c, d, {});

    var result = try graph.topologicalSort(allocator);
    defer result.deinit();

    try std.testing.expect(result.order.len == 4);
    try std.testing.expect(!result.has_cycles);

    // Check that dependencies are respected within each component
    var a_pos: usize = undefined;
    var b_pos: usize = undefined;
    var c_pos: usize = undefined;
    var d_pos: usize = undefined;

    for (result.order, 0..) |node, i| {
        if (node == a) a_pos = i;
        if (node == b) b_pos = i;
        if (node == c) c_pos = i;
        if (node == d) d_pos = i;
    }

    try std.testing.expect(a_pos < b_pos);
    try std.testing.expect(c_pos < d_pos);
}

test "Cycle detection - DAG" {
    const allocator = std.testing.allocator;

    var graph = Graph(void, void, null).init(allocator);
    defer graph.deinit();

    // Create a DAG: A -> B -> C, A -> C
    const a = try graph.addNode({});
    const b = try graph.addNode({});
    const c = try graph.addNode({});

    _ = try graph.addEdge(a, b, {});
    _ = try graph.addEdge(b, c, {});
    _ = try graph.addEdge(a, c, {});

    try std.testing.expect(!try graph.hasCycles(allocator));
}

test "Cycle detection - simple cycle" {
    const allocator = std.testing.allocator;

    var graph = Graph(void, void, null).init(allocator);
    defer graph.deinit();

    // Create a cycle: A -> B -> A
    const a = try graph.addNode({});
    const b = try graph.addNode({});

    _ = try graph.addEdge(a, b, {});
    _ = try graph.addEdge(b, a, {});

    try std.testing.expect(try graph.hasCycles(allocator));
}

test "Cycle detection - self loop" {
    const allocator = std.testing.allocator;

    var graph = Graph(void, void, null).init(allocator);
    defer graph.deinit();

    // Create a self-loop: A -> A
    const a = try graph.addNode({});
    _ = try graph.addEdge(a, a, {});

    try std.testing.expect(try graph.hasCycles(allocator));
}

test "Cycle detection - empty graph" {
    const allocator = std.testing.allocator;

    var graph = Graph(void, void, null).init(allocator);
    defer graph.deinit();

    try std.testing.expect(!try graph.hasCycles(allocator));
}

test "Graph basic operations - node and edge management" {
    const allocator = std.testing.allocator;

    var graph = Graph(u32, f32, null).init(allocator);
    defer graph.deinit();

    try std.testing.expect(graph.nodeCount() == 0);
    try std.testing.expect(graph.edgeCount() == 0);

    // Add nodes with weights
    const a = try graph.addNode(10);
    const b = try graph.addNode(20);
    const c = try graph.addNode(30);

    try std.testing.expect(graph.nodeCount() == 3);
    try std.testing.expect(graph.edgeCount() == 0);

    // Check node weights
    try std.testing.expect(graph.getNodeWeight(a) == 10);
    try std.testing.expect(graph.getNodeWeight(b) == 20);
    try std.testing.expect(graph.getNodeWeight(c) == 30);

    // Modify node weight
    graph.setNodeWeight(b, 25);
    try std.testing.expect(graph.getNodeWeight(b) == 25);

    // Add edges
    try std.testing.expect(try graph.addEdge(a, b, 1.5));
    try std.testing.expect(try graph.addEdge(a, c, 2.5));
    try std.testing.expect(try graph.addEdge(b, c, 3.5));

    try std.testing.expect(graph.edgeCount() == 3);

    // Check edge existence
    try std.testing.expect(graph.containsEdge(a, b));
    try std.testing.expect(graph.containsEdge(a, c));
    try std.testing.expect(graph.containsEdge(b, c));
    try std.testing.expect(!graph.containsEdge(b, a)); // Should be false (directed)
    try std.testing.expect(!graph.containsEdge(c, a)); // Should be false (directed)

    // Check out-degrees
    try std.testing.expect(graph.outDegree(a) == 2);
    try std.testing.expect(graph.outDegree(b) == 1);
    try std.testing.expect(graph.outDegree(c) == 0);

    // Try to add duplicate edge
    try std.testing.expect(!try graph.addEdge(a, b, 1.0)); // Should return false
    try std.testing.expect(graph.edgeCount() == 3); // Edge count shouldn't change
}
