# `phasor-graph`

A small graph library for Zig with generic node/edge types and pluggable storage backends. Inspired by petgraph, but very much a subset of
its functionality.

## Features

- [x] **Generic Graph Structure**—Support for custom node and edge weight types
- [x] **Compressed Sparse Row** storage backend (swappable)
- [x] **Graph Algorithms**
    - Dijkstra's shortest path algorithm
    - Breadth-First Search (BFS) traversal
    - Depth-First Search (DFS) traversal
    - Topological sorting with cycle detection
    - Standalone cycle detection
- [x] **Neighbor Iteration**-Efficient neighbor access with edge weights
- [x] **Visitor Pattern**-Custom visitor callbacks for graph traversals

## Usage

### Basic Graph Operations

```zig
const std = @import("std");
const Graph = @import("phasor-graph").Graph;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a graph with u32 node weights and f32 edge weights
    var graph = Graph(u32, f32, null).init(allocator);
    defer graph.deinit();

    // Add nodes
    const a = try graph.addNode(10);
    const b = try graph.addNode(20);
    const c = try graph.addNode(30);

    // Add edges
    _ = try graph.addEdge(a, b, 1.5);
    _ = try graph.addEdge(a, c, 2.0);

    // Check graph properties
    std.debug.print("Node count: {}\n", .{graph.nodeCount()});
    std.debug.print("Edge count: {}\n", .{graph.edgeCount()});
    std.debug.print("Node {} weight: {}\n", .{ a, graph.getNodeWeight(a) });
}
```

### Shortest Path Finding (Dijkstra)

```zig
pub fn findShortestPath(graph: *Graph(u32, f32, null), allocator: std.mem.Allocator, start_node: u32, target_node: u32) !void {
    // Find shortest paths from a starting node
    var result = (try graph.dijkstra(allocator, start_node)) orelse return;
    defer result.deinit();

    // Get distance to target
    const distance = result.distanceTo(target_node);
    if (distance) |dist| {
        std.debug.print("Shortest distance: {}\n", .{dist});
    }

    // Get the actual path
    const path = (try result.pathTo(allocator, target_node)) orelse return;
    defer allocator.free(path);
    for (path) |node| {
        std.debug.print("Node: {}\n", .{node});
    }
}
```

### Graph Traversal

```zig
pub fn traverseGraph(graph: *Graph(u32, f32, null), allocator: std.mem.Allocator, start_node: u32) !void {
    // BFS traversal with visitor callback
    const MyVisitor = struct {
        fn visit(node: u32) void {
            std.debug.print("Visiting node: {}\n", .{node});
        }
    };

    try graph.bfs(allocator, start_node, MyVisitor.visit);

    // DFS traversal
    try graph.dfs(allocator, start_node, MyVisitor.visit);
}
```

### Topological Sorting and Cycle Detection

```zig
pub fn analyzeGraphStructure(graph: *Graph(u32, f32, null), allocator: std.mem.Allocator) !void {
    // Topological sort (for DAGs)
    var topo_result = try graph.topologicalSort(allocator);
    defer topo_result.deinit();

    if (topo_result.has_cycles) {
        std.debug.print("Graph has cycles!\n");
    } else {
        std.debug.print("Topological order:\n");
        for (topo_result.order) |node| {
            std.debug.print("  {}\n", .{node});
        }
    }

    // Standalone cycle detection (more efficient)
    const has_cycles = try graph.hasCycles(allocator);
    std.debug.print("Has cycles: {}\n", .{has_cycles});
}
```

### Social Network Example

```zig
pub fn socialNetworkExample(allocator: std.mem.Allocator) !void {
    // Model a social network
    var social_graph = Graph([]const u8, void, null).init(allocator);
    defer social_graph.deinit();

    const alice = try social_graph.addNode("Alice");
    const bob = try social_graph.addNode("Bob");
    const charlie = try social_graph.addNode("Charlie");

    // Create friendships
    _ = try social_graph.addEdge(alice, bob, {});
    _ = try social_graph.addEdge(alice, charlie, {});

    // Find friends within degrees of separation using BFS
    const printFriend = struct {
        fn visit(node: u32) void {
            std.debug.print("Friend: {}\n", .{node});
        }
    }.visit;

    try social_graph.bfs(allocator, alice, printFriend);
}
```

## Install

At the command line:

```shell
zig fetch --save https://github.com/b33j0r/phasor-graph
```

In your `build.zig`:

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const phasor_graph = b.dependency("phasor-graph", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("phasor-graph", phasor_graph.module("phasor-graph"));
    b.installArtifact(exe);
}
```
