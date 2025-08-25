const test_graph = @import("test_graph.zig");
const test_traversal = @import("test_traversal.zig");
const test_topology = @import("test_topology.zig");
const test_dijkstra = @import("test_dijkstra.zig");
const test_real_world = @import("test_real_world.zig");

// Ensure semantic analyzer sees them
comptime {
    _ = test_graph;
    _ = test_traversal;
    _ = test_topology;
    _ = test_dijkstra;
    _ = test_real_world;
}
