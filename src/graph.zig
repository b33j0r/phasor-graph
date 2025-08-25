const std = @import("std");
const CsrStorage = @import("storage.zig").CsrStorage;

pub fn Graph(comptime NodeType: type, comptime EdgeType: type, comptime StorageType: ?type) type {
    const ActualStorage = if (StorageType) |S| S else CsrStorage(NodeType, EdgeType);

    return struct {
        const Self = @This();
        pub const Node = NodeType;
        pub const Edge = EdgeType;
        pub const Storage = ActualStorage;
        pub const NodeIndex = ActualStorage.NodeIndex;
        pub const EdgeIndex = ActualStorage.EdgeIndex;

        allocator: std.mem.Allocator,
        storage: Storage,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
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

        /// Get neighbors of a node as a slice
        pub fn neighbors(self: *Self, node: NodeIndex) []const NodeIndex {
            if (@hasDecl(Storage, "neighborsSlice")) {
                return self.storage.neighborsSlice(node);
            } else {
                @compileError("Storage implementation does not support neighbor iteration");
            }
        }

        /// Get edge weights from a node as a slice
        pub fn edges(self: *Self, node: NodeIndex) []const EdgeType {
            if (@hasDecl(Storage, "edgesSlice")) {
                return self.storage.edgesSlice(node);
            } else {
                @compileError("Storage implementation does not support edge iteration");
            }
        }

        /// Get out-degree of a node
        pub fn outDegree(self: *Self, node: NodeIndex) usize {
            if (@hasDecl(Storage, "outDegree")) {
                return self.storage.outDegree(node);
            } else {
                return self.neighbors(node).len;
            }
        }

        /// Iterator for neighbors with edge weights
        pub fn NeighborIterator(comptime G: type) type {
            return struct {
                const Iterator = @This();

                pub const Item = struct {
                    neighbor: NodeIndex,
                    edge: G.Edge,
                };

                neighbors: []const NodeIndex,
                edges: []const G.Edge,
                index: usize,

                pub fn next(iter: *Iterator) ?Item {
                    if (iter.index >= iter.neighbors.len) return null;
                    const result = Item{
                        .neighbor = iter.neighbors[iter.index],
                        .edge = iter.edges[iter.index],
                    };
                    iter.index += 1;
                    return result;
                }
            };
        }

        /// Create an iterator over neighbors and their edge weights
        pub fn neighborIterator(self: *Self, node: NodeIndex) NeighborIterator(Self) {
            return NeighborIterator(Self){
                .neighbors = self.neighbors(node),
                .edges = self.edges(node),
                .index = 0,
            };
        }

        /// Dijkstra's shortest path algorithm
        /// Returns distances from start node to all reachable nodes
        /// Edge weights must be numeric and support addition and comparison
        pub fn dijkstra(self: *Self, allocator: std.mem.Allocator, start: NodeIndex) !?@import("dijkstra.zig").DijkstraResult(EdgeType) {
            const QueueItemType = @import("dijkstra.zig").QueueItem(EdgeType);
            const PriorityQueue = std.PriorityQueue(QueueItemType, void, @import("dijkstra.zig").compareQueueItems(EdgeType));

            const n = self.nodeCount();
            if (start >= n) return null;

            var distances = try allocator.alloc(?EdgeType, n);
            defer allocator.free(distances);
            var visited = try allocator.alloc(bool, n);
            defer allocator.free(visited);
            var predecessors = try allocator.alloc(?NodeIndex, n);
            defer allocator.free(predecessors);

            // Initialize
            @memset(distances, null);
            @memset(visited, false);
            @memset(predecessors, null);
            distances[start] = @import("dijkstra.zig").getZeroValue(EdgeType);

            var queue = PriorityQueue.init(allocator, {});
            defer queue.deinit();

            try queue.add(QueueItemType{ .node = start, .distance = @import("dijkstra.zig").getZeroValue(EdgeType) });

            while (queue.count() > 0) {
                const current = queue.remove();
                if (visited[current.node]) continue;
                visited[current.node] = true;

                var iter = self.neighborIterator(current.node);
                while (iter.next()) |neighbor_info| {
                    const neighbor = neighbor_info.neighbor;
                    const edge_weight = neighbor_info.edge;

                    if (visited[neighbor]) continue;

                    const new_distance = @import("dijkstra.zig").addWeights(EdgeType, distances[current.node].?, edge_weight);

                    if (distances[neighbor] == null or @import("dijkstra.zig").compareWeights(EdgeType, new_distance, distances[neighbor].?) == .lt) {
                        distances[neighbor] = new_distance;
                        predecessors[neighbor] = current.node;
                        try queue.add(QueueItemType{ .node = neighbor, .distance = new_distance });
                    }
                }
            }

            // Copy results to owned arrays
            const result_distances = try allocator.alloc(?EdgeType, n);
            const result_predecessors = try allocator.alloc(?NodeIndex, n);
            @memcpy(result_distances, distances);
            @memcpy(result_predecessors, predecessors);

            return @import("dijkstra.zig").DijkstraResult(EdgeType){
                .distances = result_distances,
                .predecessors = result_predecessors,
                .start = start,
                .allocator = allocator,
            };
        }

        /// Breadth-first search from a start node
        /// Calls visitor function for each node in BFS order
        pub fn bfs(self: *Self, allocator: std.mem.Allocator, start: NodeIndex, visitor: anytype) !void {
            const n = self.nodeCount();
            if (start >= n) return;

            var visited = try allocator.alloc(bool, n);
            defer allocator.free(visited);
            // TODO: Use Zig vector for visited array initialization when n is vectorizable
            @memset(visited, false);

            var queue = std.ArrayListUnmanaged(NodeIndex).empty;
            defer queue.deinit(allocator);

            try queue.append(allocator, start);
            visited[start] = true;

            while (queue.items.len > 0) {
                const current = queue.orderedRemove(0);
                visitor(current);

                const neighbors_slice = self.neighbors(current);
                for (neighbors_slice) |neighbor| {
                    if (!visited[neighbor]) {
                        visited[neighbor] = true;
                        try queue.append(allocator, neighbor);
                    }
                }
            }
        }

        /// Depth-first search from a start node
        /// Calls visitor function for each node in DFS order
        pub fn dfs(self: *Self, allocator: std.mem.Allocator, start: NodeIndex, visitor: anytype) !void {
            const n = self.nodeCount();
            if (start >= n) return;

            const visited = try allocator.alloc(bool, n);
            defer allocator.free(visited);
            @memset(visited, false);

            try self.dfsRecursive(start, visited, visitor);
        }

        fn dfsRecursive(self: *Self, node: NodeIndex, visited: []bool, visitor: anytype) !void {
            visited[node] = true;
            visitor(node);

            const neighbors_slice = self.neighbors(node);
            for (neighbors_slice) |neighbor| {
                if (!visited[neighbor]) {
                    try self.dfsRecursive(neighbor, visited, visitor);
                }
            }
        }

        /// Topological sort result
        pub const TopologicalSortResult = struct {
            /// Topologically sorted node indices
            order: []NodeIndex,
            /// True if the graph has cycles (partial order returned)
            has_cycles: bool,
            allocator: std.mem.Allocator,

            pub fn deinit(self: *TopologicalSortResult) void {
                self.allocator.free(self.order);
            }
        };

        /// Kahn's algorithm for topological sorting
        /// Returns nodes in dependency order (dependencies come before dependents)
        /// If the graph has cycles, returns partial order and sets has_cycles to true
        /// TODO: SIMD acceleration for in-degree calculations and batch queue operations
        pub fn topologicalSort(self: *Self, allocator: std.mem.Allocator) !TopologicalSortResult {
            const n = self.nodeCount();
            if (n == 0) {
                return TopologicalSortResult{
                    .order = try allocator.alloc(NodeIndex, 0),
                    .has_cycles = false,
                    .allocator = allocator,
                };
            }

            // Calculate in-degrees for all nodes
            var in_degrees = try allocator.alloc(u32, n);
            defer allocator.free(in_degrees);
            @memset(in_degrees, 0);

            // Count incoming edges for each node
            for (0..n) |node| {
                const neighbors_slice = self.neighbors(@intCast(node));
                for (neighbors_slice) |neighbor| {
                    in_degrees[neighbor] += 1;
                }
            }

            // Initialize queue with nodes that have no incoming edges
            var queue = std.ArrayListUnmanaged(NodeIndex).empty;
            defer queue.deinit(allocator);

            for (0..n) |i| {
                if (in_degrees[i] == 0) {
                    try queue.append(allocator, @intCast(i));
                }
            }

            // Process nodes in topological order
            var result = std.ArrayListUnmanaged(NodeIndex).empty;
            defer result.deinit(self.allocator);

            while (queue.items.len > 0) {
                const current = queue.orderedRemove(0);
                try result.append(allocator, current);

                // Reduce in-degree for all neighbors
                const neighbors_slice = self.neighbors(current);
                for (neighbors_slice) |neighbor| {
                    in_degrees[neighbor] -= 1;
                    if (in_degrees[neighbor] == 0) {
                        try queue.append(allocator, neighbor);
                    }
                }
            }

            const has_cycles = result.items.len != n;

            return TopologicalSortResult{
                .order = try result.toOwnedSlice(self.allocator),
                .has_cycles = has_cycles,
                .allocator = allocator,
            };
        }

        /// Color enum for cycle detection DFS
        const Color = enum { white, gray, black };

        /// Check if the graph has any cycles using DFS
        /// This is more efficient than topological sort if you only need to detect cycles
        pub fn hasCycles(self: *Self, allocator: std.mem.Allocator) !bool {
            const n = self.nodeCount();
            if (n == 0) return false;

            const colors = try allocator.alloc(Color, n);
            defer allocator.free(colors);
            @memset(colors, .white);

            // Check each component
            for (0..n) |i| {
                if (colors[i] == .white) {
                    if (try self.dfsHasCycles(@intCast(i), colors)) {
                        return true;
                    }
                }
            }

            return false;
        }

        /// Internal DFS function for cycle detection
        /// Uses three-color approach: white (unvisited), gray (being processed), black (finished)
        fn dfsHasCycles(self: *Self, node: NodeIndex, colors: []Color) !bool {
            colors[node] = .gray;

            const neighbors_slice = self.neighbors(node);
            for (neighbors_slice) |neighbor| {
                switch (colors[neighbor]) {
                    .gray => return true, // Back edge found - cycle detected
                    .white => {
                        if (try self.dfsHasCycles(neighbor, colors)) {
                            return true;
                        }
                    },
                    .black => {}, // Already processed, skip
                }
            }

            colors[node] = .black;
            return false;
        }
    };
}
