const std = @import("std");
const graph = @import("phasor-graph");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const N = struct {
        id: usize,
        name: []const u8,
    };
    const E = struct {
        terrain: union(enum) {
            grass,
            water,
            mountain,
        },

        const Self = @This();

        pub fn cost(self: Self) u32 {
            return switch (self.terrain) {
                .grass => 1,
                .water => 2,
                .mountain => 3,
            };
        }
    };

    var g = graph.Graph(N, E, null).init(allocator);
    defer g.deinit();
}
