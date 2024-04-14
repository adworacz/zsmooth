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
///
/// Quickly generated using this rough script (my sed and awk foo is weak, but it works):
/// echo '<array values from sorter hunter>' | sed 's/[()]//g' | sed 's/\[/{/g' | sed 's/\]/}/g' | awk '{ print "&[_]usize"$1"," }'
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
        11 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
            &[_]usize{ 0, 2, 1, 3, 4, 6, 5, 7 },
            &[_]usize{ 1, 2, 5, 6 },
            &[_]usize{ 0, 5, 1, 4, 2, 7, 3, 6 },
            &[_]usize{ 2, 5, 3, 4 },
            &[_]usize{ 2, 8, 4, 9 },
            &[_]usize{ 8, 10 },
            &[_]usize{ 3, 8, 5, 10 },
            &[_]usize{ 4, 5 },
            &[_]usize{ 4, 8 },
            &[_]usize{ 5, 8 },
        }).sort(T, N, input),
        13 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
            &[_]usize{ 0, 8, 1, 9, 2, 4, 3, 5, 6, 10, 7, 11 },
            &[_]usize{ 0, 6, 1, 7, 3, 4, 8, 10, 9, 11 },
            &[_]usize{ 2, 6, 3, 10, 4, 8, 5, 9 },
            &[_]usize{ 1, 3, 4, 6, 7, 8 },
            &[_]usize{ 3, 12, 5, 6 },
            &[_]usize{ 3, 5, 6, 12 },
            &[_]usize{ 5, 7, 6, 10 },
            &[_]usize{ 5, 6 },
            &[_]usize{ 6, 7 },
        }).sort(T, N, input),
        15 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 },
            &[_]usize{ 0, 12, 1, 13, 2, 8, 3, 9, 10, 14 },
            &[_]usize{ 3, 11, 10, 12 },
            &[_]usize{ 2, 10, 3, 6, 5, 11, 7, 12 },
            &[_]usize{ 0, 3, 4, 10, 5, 6, 7, 8, 9, 12 },
            &[_]usize{ 1, 5, 3, 10, 6, 13, 8, 11 },
            &[_]usize{ 1, 3, 5, 8, 6, 10 },
            &[_]usize{ 3, 7, 5, 14, 6, 9 },
            &[_]usize{ 4, 7, 5, 6, 8, 14, 9, 10 },
            &[_]usize{ 6, 7, 8, 9 },
            &[_]usize{ 6, 8 },
            &[_]usize{ 7, 8 },
        }).sort(T, N, input),
        17 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
            &[_]usize{ 0, 2, 1, 3, 4, 6, 5, 7, 8, 10, 9, 11, 12, 14, 13, 15 },
            &[_]usize{ 1, 2, 5, 13, 6, 14, 9, 10 },
            &[_]usize{ 1, 9, 2, 10, 5, 6, 13, 14 },
            &[_]usize{ 1, 4, 2, 13, 5, 8, 6, 9, 7, 10, 11, 14 },
            &[_]usize{ 2, 6, 4, 7, 8, 11, 9, 13 },
            &[_]usize{ 0, 8, 3, 11, 4, 12, 7, 15, 9, 16 },
            &[_]usize{ 3, 8, 6, 9, 7, 12 },
            &[_]usize{ 3, 7, 8, 16 },
            &[_]usize{ 7, 9, 8, 12 },
            &[_]usize{ 6, 7, 8, 9 },
            &[_]usize{ 7, 8 },
        }).sort(T, N, input),
        19 => SortingNetwork([_]Layer{
            // TODO: Try out some of the other sorting networks provided by sorter hunter
            // to see if there's a performance difference.
            &[_]usize{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 },
            &[_]usize{ 0, 2, 3, 5, 4, 6, 7, 9, 8, 10, 11, 13, 12, 14, 15, 17 },
            &[_]usize{ 0, 4, 1, 5, 2, 14, 3, 15, 12, 16, 13, 17 },
            &[_]usize{ 0, 13, 1, 12, 2, 6, 4, 17, 5, 16, 11, 15 },
            &[_]usize{ 0, 1, 4, 12, 5, 13, 16, 17 },
            &[_]usize{ 4, 13, 5, 9, 8, 12 },
            &[_]usize{ 4, 7, 5, 11, 6, 12, 10, 13 },
            &[_]usize{ 1, 11, 6, 16, 7, 8, 9, 10 },
            &[_]usize{ 2, 8, 6, 10, 7, 11, 9, 15 },
            &[_]usize{ 2, 9, 3, 11, 6, 14, 8, 15 },
            &[_]usize{ 6, 9, 8, 11 },
            &[_]usize{ 6, 8, 9, 11 },
            &[_]usize{ 8, 9 },
            &[_]usize{ 9, 18 },
            &[_]usize{ 8, 9 },
        }).sort(T, N, input),
        21 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 },
            &[_]usize{ 0, 2, 1, 3, 4, 6, 5, 7, 8, 10, 9, 11, 12, 14, 13, 15, 16, 18, 17, 19 },
            &[_]usize{ 1, 5, 2, 6, 3, 15, 4, 16, 13, 17, 14, 18 },
            &[_]usize{ 1, 14, 2, 13, 3, 7, 5, 18, 6, 17, 12, 16 },
            &[_]usize{ 0, 16, 1, 2, 3, 19, 5, 13, 6, 14, 17, 18 },
            &[_]usize{ 0, 4, 5, 14, 6, 10, 9, 13, 15, 19 },
            &[_]usize{ 5, 8, 6, 12, 7, 13, 11, 14 },
            &[_]usize{ 2, 12, 7, 17, 8, 9, 10, 11 },
            &[_]usize{ 3, 9, 7, 11, 8, 12, 10, 16 },
            &[_]usize{ 3, 10, 4, 12, 7, 15, 9, 16 },
            &[_]usize{ 7, 10, 9, 12 },
            &[_]usize{ 7, 9, 10, 12 },
            &[_]usize{ 9, 10 },
            &[_]usize{ 10, 20 },
            &[_]usize{ 9, 10 },
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

    var input11 = [_]u8{ 10, 11, 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    median(u8, input11.len, &input11);
    try std.testing.expectEqual(6, input11[5]);

    var input13 = [_]u8{ 12, 13, 10, 11, 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    median(u8, input13.len, &input13);
    try std.testing.expectEqual(7, input13[6]);

    var input15 = [_]u8{ 14, 15, 12, 13, 10, 11, 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    median(u8, input15.len, &input15);
    try std.testing.expectEqual(8, input15[7]);

    var input17 = [_]u8{ 16, 17, 14, 15, 12, 13, 10, 11, 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    median(u8, input17.len, &input17);
    try std.testing.expectEqual(9, input17[8]);

    var input19 = [_]u8{ 18, 19, 16, 17, 14, 15, 12, 13, 10, 11, 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    median(u8, input19.len, &input19);
    try std.testing.expectEqual(10, input19[9]);

    var input21 = [_]u8{ 20, 21, 18, 19, 16, 17, 14, 15, 12, 13, 10, 11, 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    median(u8, input21.len, &input21);
    try std.testing.expectEqual(11, input21[10]);
}
