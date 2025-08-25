const std = @import("std");
const Graph = @import("phasor-graph").Graph;

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
