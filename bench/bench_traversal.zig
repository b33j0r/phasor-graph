const std = @import("std");
const phasor = @import("phasor-graph");
const Graph = phasor.Graph;
const CsrStorage = phasor.CsrStorage;
const MatrixStorage = phasor.MatrixStorage;

// Benchmark configuration for traversal
const TraversalBenchConfig = struct {
    node_counts: []const usize = &.{ 500, 1000, 2000 },
    edge_density: f64 = 0.05, // 5% edge density for traversal tests
    iterations: usize = 10,
};

// Benchmark result structure
const BenchResult = struct {
    name: []const u8,
    storage_type: []const u8,
    node_count: usize,
    edge_count: usize,
    time_ns: u64,
    nodes_visited: usize,
};

// Timer utility
const Timer = struct {
    start: std.time.Instant,

    fn init() Timer {
        return Timer{
            .start = std.time.Instant.now() catch unreachable,
        };
    }

    fn elapsed(self: Timer) u64 {
        const end = std.time.Instant.now() catch unreachable;
        return end.since(self.start);
    }
};

// BFS benchmark
fn benchBFS(allocator: std.mem.Allocator, graph: anytype, start_node: u32) !usize {
    var visited_count: usize = 0;

    const TestContext = struct {
        var count: *usize = undefined;

        fn visit(node: u32) void {
            count.* += 1;
            std.mem.doNotOptimizeAway(node);
        }
    };

    TestContext.count = &visited_count;
    try graph.bfs(allocator, start_node, TestContext.visit);

    return visited_count;
}

// DFS benchmark
fn benchDFS(allocator: std.mem.Allocator, graph: anytype, start_node: u32) !usize {
    var visited_count: usize = 0;

    const TestContext = struct {
        var count: *usize = undefined;

        fn visit(node: u32) void {
            count.* += 1;
            std.mem.doNotOptimizeAway(node);
        }
    };

    TestContext.count = &visited_count;
    try graph.dfs(allocator, start_node, TestContext.visit);

    return visited_count;
}

// Dijkstra's algorithm benchmark
fn benchDijkstra(allocator: std.mem.Allocator, graph: anytype, start_node: u32) !usize {
    var result = (try graph.dijkstra(allocator, start_node)) orelse return 0;
    defer result.deinit();
    
    var reachable_count: usize = 0;
    for (result.distances) |distance| {
        if (distance != std.math.inf(f32)) {
            reachable_count += 1;
            std.mem.doNotOptimizeAway(distance);
        }
    }
    
    return reachable_count;
}

// Run traversal benchmark
fn runTraversalBenchmark(
    allocator: std.mem.Allocator,
    comptime StorageType: type,
    storage_name: []const u8,
    bench_name: []const u8,
    node_count: usize,
    edge_count: usize,
    bench_fn: fn (allocator: std.mem.Allocator, anytype, u32) anyerror!usize,
) !BenchResult {
    var graph = Graph(u32, f32, StorageType).init(allocator);
    defer graph.deinit();

    // Pre-populate graph with nodes
    for (0..node_count) |i| {
        _ = try graph.addNode(@intCast(i));
    }

    // Add edges based on edge_count with more structured pattern for better connectivity
    var edges_added: usize = 0;

    // Create a more connected graph for traversal
    for (0..node_count) |i| {
        // Add some forward edges for connectivity
        const connections_per_node = @min(5, node_count / 10);
        for (0..connections_per_node) |j| {
            const target = (i + j + 1) % node_count;
            if (i != target and edges_added < edge_count) {
                const weight = @as(f32, @floatFromInt(i + target + 1));
                _ = try graph.addEdge(@intCast(i), @intCast(target), weight);
                edges_added += 1;
            }
        }
    }

    // Add some random edges for the remaining edge count
    var rng = std.Random.DefaultPrng.init(42);
    const random = rng.random();

    while (edges_added < edge_count) {
        const source = random.intRangeAtMost(u32, 0, @intCast(node_count - 1));
        const target = random.intRangeAtMost(u32, 0, @intCast(node_count - 1));

        if (source != target and !graph.containsEdge(source, target)) {
            const weight = random.float(f32) * 100.0;
            _ = try graph.addEdge(source, target, weight);
            edges_added += 1;
        }
    }

    // Run benchmark starting from node 0
    const timer = Timer.init();
    const nodes_visited = try bench_fn(allocator, &graph, 0);
    const elapsed = timer.elapsed();

    return BenchResult{
        .name = bench_name,
        .storage_type = storage_name,
        .node_count = node_count,
        .edge_count = edges_added,
        .time_ns = elapsed,
        .nodes_visited = nodes_visited,
    };
}

fn printTraversalResults(results: []const BenchResult) void {
    std.debug.print("\n=== Traversal Benchmark Results ===\n\n", .{});
    std.debug.print("{s:<20} {s:<12} {s:<8} {s:<8} {s:<12} {s:<12}\n", .{ "Algorithm", "Storage", "Nodes", "Edges", "Time (μs)", "Visited" });
    std.debug.print("{s}\n", .{"-" ** 80});

    for (results) |result| {
        const time_us = result.time_ns / 1000;
        std.debug.print("{s:<20} {s:<12} {d:<8} {d:<8} {d:<12} {d:<12}\n", .{
            result.name,
            result.storage_type,
            result.node_count,
            result.edge_count,
            time_us,
            result.nodes_visited,
        });
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = TraversalBenchConfig{};
    var results = std.ArrayListUnmanaged(BenchResult){};
    defer results.deinit(allocator);

    std.debug.print("Running traversal benchmarks comparing CsrStorage vs MatrixStorage...\n", .{});

    // Run benchmarks for each configuration
    for (config.node_counts) |node_count| {
        const edge_count = @as(usize, @intFromFloat(@as(f64, @floatFromInt(node_count * node_count)) * config.edge_density));

        std.debug.print("Testing with {} nodes, {} edges...\n", .{ node_count, edge_count });

        // BFS Benchmark
        {
            const csr_result = try runTraversalBenchmark(
                allocator,
                CsrStorage(u32, f32),
                "CSR",
                "BFS",
                node_count,
                edge_count,
                benchBFS,
            );
            try results.append(allocator, csr_result);

            const matrix_result = try runTraversalBenchmark(
                allocator,
                MatrixStorage(u32, f32),
                "Matrix",
                "BFS",
                node_count,
                edge_count,
                benchBFS,
            );
            try results.append(allocator, matrix_result);
        }

        // DFS Benchmark
        {
            const csr_result = try runTraversalBenchmark(
                allocator,
                CsrStorage(u32, f32),
                "CSR",
                "DFS",
                node_count,
                edge_count,
                benchDFS,
            );
            try results.append(allocator, csr_result);

            const matrix_result = try runTraversalBenchmark(
                allocator,
                MatrixStorage(u32, f32),
                "Matrix",
                "DFS",
                node_count,
                edge_count,
                benchDFS,
            );
            try results.append(allocator, matrix_result);
        }

        // Dijkstra Benchmark
        {
            const csr_result = try runTraversalBenchmark(
                allocator,
                CsrStorage(u32, f32),
                "CSR",
                "Dijkstra",
                node_count,
                edge_count,
                benchDijkstra,
            );
            try results.append(allocator, csr_result);

            const matrix_result = try runTraversalBenchmark(
                allocator,
                MatrixStorage(u32, f32),
                "Matrix",
                "Dijkstra",
                node_count,
                edge_count,
                benchDijkstra,
            );
            try results.append(allocator, matrix_result);
        }
    }

    printTraversalResults(results.items);
}
