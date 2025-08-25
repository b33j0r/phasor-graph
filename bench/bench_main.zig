const std = @import("std");
const phasor = @import("phasor-graph");
const Graph = phasor.Graph;
const CsrStorage = phasor.CsrStorage;
const MatrixStorage = phasor.MatrixStorage;

// Benchmark configuration
const BenchConfig = struct {
    node_counts: []const usize = &.{ 100, 500, 1000, 2000 },
    edge_density: f64 = 0.1, // 10% edge density
    iterations: usize = 100,
};

// Benchmark result structure
const BenchResult = struct {
    name: []const u8,
    storage_type: []const u8,
    node_count: usize,
    edge_count: usize,
    time_ns: u64,
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

// Simplified benchmark - no memory tracking to avoid compatibility issues

// Benchmark runner
fn runBenchmark(
    allocator: std.mem.Allocator,
    comptime StorageType: type,
    storage_name: []const u8,
    bench_name: []const u8,
    node_count: usize,
    edge_count: usize,
    bench_fn: fn (allocator: std.mem.Allocator, anytype) anyerror!void,
) !BenchResult {
    var graph = Graph(u32, f32, StorageType).init(allocator);
    defer graph.deinit();

    // Pre-populate graph with nodes
    for (0..node_count) |i| {
        _ = try graph.addNode(@intCast(i));
    }

    // Add edges based on edge_count
    const total_possible_edges = node_count * (node_count - 1);
    const step = if (edge_count > 0) total_possible_edges / edge_count else total_possible_edges;
    var edges_added: usize = 0;

    for (0..node_count) |i| {
        for (0..node_count) |j| {
            if (i != j and (i * node_count + j) % step == 0 and edges_added < edge_count) {
                _ = try graph.addEdge(@intCast(i), @intCast(j), @as(f32, @floatFromInt(i + j)));
                edges_added += 1;
            }
        }
    }

    // Run benchmark
    const timer = Timer.init();
    try bench_fn(allocator, &graph);
    const elapsed = timer.elapsed();

    return BenchResult{
        .name = bench_name,
        .storage_type = storage_name,
        .node_count = node_count,
        .edge_count = edges_added,
        .time_ns = elapsed,
    };
}

// Generic benchmark functions
fn benchGraphConstruction(allocator: std.mem.Allocator, graph: anytype) !void {
    _ = allocator;

    // Add additional nodes during benchmark
    const additional_nodes = 100;
    const base: usize = graph.nodeCount();
    for (0..additional_nodes) |i| {
        _ = try graph.addNode(@intCast(base + i));
    }

    // Add edges between new nodes
    for (0..additional_nodes) |i| {
        for (0..additional_nodes) |j| {
            if (i != j and (i + j) % 10 == 0) {
                _ = try graph.addEdge(@intCast(base + i), @intCast(base + j), @as(f32, @floatFromInt(i + j)));
            }
        }
    }
}

fn benchEdgeLookup(allocator: std.mem.Allocator, graph: anytype) !void {
    _ = allocator;

    const node_count = graph.nodeCount();
    var lookup_count: usize = 0;

    // Perform edge lookups
    for (0..node_count) |i| {
        for (0..node_count) |j| {
            if (graph.containsEdge(@intCast(i), @intCast(j))) {
                lookup_count += 1;
            }
        }
    }

    // Prevent optimization
    std.mem.doNotOptimizeAway(lookup_count);
}

fn benchNeighborIteration(allocator: std.mem.Allocator, graph: anytype) !void {
    _ = allocator;

    const node_count = graph.nodeCount();
    var total_neighbors: usize = 0;

    // Iterate through all neighbors
    for (0..node_count) |i| {
        var iter = graph.neighborIterator(@intCast(i));
        while (iter.next()) |neighbor| {
            total_neighbors += 1;
            std.mem.doNotOptimizeAway(neighbor.neighbor);
            std.mem.doNotOptimizeAway(neighbor.edge);
        }
    }

    std.mem.doNotOptimizeAway(total_neighbors);
}

fn printResults(results: []const BenchResult) void {
    std.debug.print("\n=== Benchmark Results ===\n\n", .{});
    std.debug.print("{s:<25} {s:<12} {s:<8} {s:<8} {s:<15}\n", .{ "Benchmark", "Storage", "Nodes", "Edges", "Time (μs)" });
    std.debug.print("{s}\n", .{"-" ** 70});

    for (results) |result| {
        const time_us = result.time_ns / 1000;
        std.debug.print("{s:<25} {s:<12} {d:<8} {d:<8} {d:<15}\n", .{
            result.name,
            result.storage_type,
            result.node_count,
            result.edge_count,
            time_us,
        });
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = BenchConfig{};
    var results = std.ArrayListUnmanaged(BenchResult){};
    defer results.deinit(allocator);

    std.debug.print("Running benchmarks comparing CsrStorage vs MatrixStorage...\n", .{});

    // Run benchmarks for each configuration
    for (config.node_counts) |node_count| {
        const edge_count = @as(usize, @intFromFloat(@as(f64, @floatFromInt(node_count * node_count)) * config.edge_density));

        std.debug.print("Testing with {} nodes, {} edges...\n", .{ node_count, edge_count });

        // Graph Construction Benchmark
        {
            const csr_result = try runBenchmark(
                allocator,
                CsrStorage(u32, f32),
                "CSR",
                "Graph Construction",
                node_count,
                edge_count,
                benchGraphConstruction,
            );
            try results.append(allocator, csr_result);

            const matrix_result = try runBenchmark(
                allocator,
                MatrixStorage(u32, f32),
                "Matrix",
                "Graph Construction",
                node_count,
                edge_count,
                benchGraphConstruction,
            );
            try results.append(allocator, matrix_result);
        }

        // Edge Lookup Benchmark
        {
            const csr_result = try runBenchmark(
                allocator,
                CsrStorage(u32, f32),
                "CSR",
                "Edge Lookup",
                node_count,
                edge_count,
                benchEdgeLookup,
            );
            try results.append(allocator, csr_result);

            const matrix_result = try runBenchmark(
                allocator,
                MatrixStorage(u32, f32),
                "Matrix",
                "Edge Lookup",
                node_count,
                edge_count,
                benchEdgeLookup,
            );
            try results.append(allocator, matrix_result);
        }

        // Neighbor Iteration Benchmark
        {
            const csr_result = try runBenchmark(
                allocator,
                CsrStorage(u32, f32),
                "CSR",
                "Neighbor Iteration",
                node_count,
                edge_count,
                benchNeighborIteration,
            );
            try results.append(allocator, csr_result);

            const matrix_result = try runBenchmark(
                allocator,
                MatrixStorage(u32, f32),
                "Matrix",
                "Neighbor Iteration",
                node_count,
                edge_count,
                benchNeighborIteration,
            );
            try results.append(allocator, matrix_result);
        }
    }

    printResults(results.items);
}
