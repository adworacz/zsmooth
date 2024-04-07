const std = @import("std");

fn compareSwap(comptime T: type, a: *T, b: *T) void {
    const min = @min(a.*, b.*);
    b.* = @max(a.*, b.*);
    a.* = min;
}

// Sorting network is comprised of:
// 1. compare-n-swap operations (min/max)
// 2. layers of compare-n-swaps
// 3. To form a network.

// const Pairs = []usize;
// const Layers = []Pairs;

pub fn SortingNetwork(comptime layers: anytype) type {
    return struct {
        pub fn sort(comptime T: type, comptime N: usize, input: *[N]T) void {

            // For each layer, get swap pairs.
            // Iterate over swap pairs.
            inline for (layers) |layer| {
                comptime var i: usize = 0;
                inline while (i < layer.len) : (i += 2) {
                    const a = layer[i];
                    const b = layer[i + 1];
                    compareSwap(T, &input[a], &input[b]);
                }
            }
        }
    };
}

pub fn median(comptime T: type, comptime N: usize, input: *[N]T) void {
    switch (N) {
        3 => SortingNetwork([_][]const usize{
            &[_]usize{ 0, 1 },
            &[_]usize{ 1, 2 },
            &[_]usize{ 0, 1 },
        }).sort(T, N, input),
        5 => SortingNetwork([_][]const usize{
            &[_]usize{ 0, 1, 2, 3 },
            &[_]usize{ 0, 2, 1, 3 },
            &[_]usize{ 2, 4 },
            &[_]usize{ 1, 2 },
            &[_]usize{ 2, 4 },
        }).sort(T, N, input),
        else => unreachable,
    }
}

test "Sorting Networks - Median" {
    var input3 = [_]u8{ 3, 1, 2 };
    median(u8, input3.len, &input3);
    try std.testing.expectEqual(2, input3[1]);

    var input5 = [_]u8{ 3, 1, 5, 2, 4 };
    median(u8, input5.len, &input5);
    try std.testing.expectEqual(3, input5[2]);
}
