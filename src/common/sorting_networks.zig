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

/// Uses sorting networks to find the median of an array/slice of values.
///
/// Based on the wonderful work of the SorterHunter project:
/// https://github.com/bertdobbelaere/SorterHunter
///
/// Specifically, see the network values used for medians here:
/// https://bertdobbelaere.github.io/median_networks.html
pub fn median(comptime T: type, comptime N: usize, input: *[N]T) void {
    // Only odd number networks are currently supported.
    std.debug.assert(N % 2 == 1);
    const Layer = []const usize;
    switch (N) {
        // https://bertdobbelaere.github.io/median_networks.html#N3L3D3
        3 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1 },
            &[_]usize{ 1, 2 },
            &[_]usize{ 0, 1 },
        }).sort(T, N, input),
        // https://bertdobbelaere.github.io/median_networks.html#N5L7D5
        5 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3 },
            &[_]usize{ 0, 2, 1, 3 },
            &[_]usize{ 2, 4 },
            &[_]usize{ 1, 2 },
            &[_]usize{ 2, 4 },
        }).sort(T, N, input),
        // https://bertdobbelaere.github.io/median_networks.html#N7L13D6
        7 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 6, 1, 2, 3, 4 },
            &[_]usize{ 0, 2, 1, 4, 3, 5 },
            &[_]usize{ 0, 1, 2, 5, 4, 6 },
            &[_]usize{ 1, 3, 2, 4 },
            &[_]usize{ 3, 4 },
            &[_]usize{ 2, 3 },
        }).sort(T, N, input),
        // https://bertdobbelaere.github.io/median_networks.html#N9L19D7
        9 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 7, 1, 2, 3, 5, 4, 8 },
            &[_]usize{ 0, 2, 1, 5, 3, 8, 4, 7 },
            &[_]usize{ 0, 3, 1, 4, 2, 8, 5, 7 },
            &[_]usize{ 3, 4, 5, 6 },
            &[_]usize{ 2, 5, 4, 6 },
            &[_]usize{ 2, 3, 4, 5 },
            &[_]usize{ 3, 4 },
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

    var input7 = [_]u8{ 6, 3, 1, 5, 2, 4, 7 };
    median(u8, input7.len, &input7);
    try std.testing.expectEqual(4, input7[3]);

    var input9 = [_]u8{ 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    median(u8, input9.len, &input9);
    try std.testing.expectEqual(5, input9[4]);
}
