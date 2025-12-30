const std = @import("std");
const vec = @import("vector.zig");
const types = @import("type.zig");
const math = @import("math.zig");

fn compareSwap(comptime T: type, a: *T, b: *T) void {
    const min = vec.minFast(a.*, b.*);
    b.* = vec.maxFast(a.*, b.*);
    a.* = min;
}

// Sorting network is comprised of:
// 1. compare-n-swap operations (min/max)
// 2. layers of compare-n-swaps
// 3. To form a network.
pub fn SortingNetwork(comptime layers: anytype) type {
    return struct {
        pub fn sort(comptime T: type, input: []T) void {
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
pub fn median(comptime T: type, input: []T) T {
    const Layer = []const usize;
    switch (input.len) {
        1 => {},
        2 => {},
        // https://bertdobbelaere.github.io/median_networks.html#N3L3D3
        3 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1 },
            &[_]usize{ 1, 2 },
            &[_]usize{ 0, 1 },
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N4L4D2
        4 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3 },
            &[_]usize{ 0, 2, 1, 3 },
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N5L7D5
        5 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3 },
            &[_]usize{ 0, 2, 1, 3 },
            &[_]usize{ 2, 4 },
            &[_]usize{ 1, 2 },
            &[_]usize{ 2, 4 },
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N6L10D4
        6 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 4, 5 },
            &[_]usize{ 0, 5, 1, 3, 2, 4 },
            &[_]usize{ 0, 2, 1, 4, 3, 5 },
            &[_]usize{ 1, 2, 3, 4 },
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N7L13D6
        7 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 6, 1, 2, 3, 4 },
            &[_]usize{ 0, 2, 1, 4, 3, 5 },
            &[_]usize{ 0, 1, 2, 5, 4, 6 },
            &[_]usize{ 1, 3, 2, 4 },
            &[_]usize{ 3, 4 },
            &[_]usize{ 2, 3 },
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N8L16D5
        8 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 2, 1, 3, 4, 6, 5, 7 },
            &[_]usize{ 0, 4, 1, 5, 2, 6, 3, 7 },
            &[_]usize{ 0, 1, 2, 4, 3, 5, 6, 7 },
            &[_]usize{ 2, 3, 4, 5 },
            &[_]usize{ 1, 4, 3, 6 },
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N9L19D7
        9 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 7, 1, 2, 3, 5, 4, 8 },
            &[_]usize{ 0, 2, 1, 5, 3, 8, 4, 7 },
            &[_]usize{ 0, 3, 1, 4, 2, 8, 5, 7 },
            &[_]usize{ 3, 4, 5, 6 },
            &[_]usize{ 2, 5, 4, 6 },
            &[_]usize{ 2, 3, 4, 5 },
            &[_]usize{ 3, 4 },
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N10L22D8
        10 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 3, 5, 4, 6, 8, 9 },
            &[_]usize{ 0, 3, 1, 5, 4, 8, 6, 9 },
            &[_]usize{ 1, 3, 6, 8 },
            &[_]usize{ 0, 6, 1, 4, 3, 9, 5, 8 },
            &[_]usize{ 2, 6, 3, 7 },
            &[_]usize{ 2, 3, 6, 7 },
            &[_]usize{ 3, 4, 5, 6 },
            &[_]usize{ 3, 5, 4, 6 },
        }).sort(T, input),
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
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N12L29D7
        12 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
            &[_]usize{ 0, 2, 1, 3, 4, 6, 5, 7, 8, 10, 9, 11 },
            &[_]usize{ 0, 4, 1, 10, 2, 9, 5, 6, 7, 11 },
            &[_]usize{ 2, 6, 3, 7, 4, 8, 5, 9 },
            &[_]usize{ 1, 5, 2, 8, 3, 9, 6, 10 },
            &[_]usize{ 3, 5, 6, 8 },
            &[_]usize{ 3, 6, 5, 8 },
        }).sort(T, input),
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
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N14L38D10
        14 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 },
            &[_]usize{ 0, 9, 2, 10, 3, 11, 4, 13 },
            &[_]usize{ 0, 12, 1, 13, 4, 6, 7, 9 },
            &[_]usize{ 0, 4, 1, 10, 3, 12, 5, 7, 6, 8, 9, 13 },
            &[_]usize{ 1, 8, 2, 4, 5, 12, 9, 11 },
            &[_]usize{ 1, 5, 3, 4, 8, 12, 9, 10 },
            &[_]usize{ 3, 5, 4, 9, 8, 10 },
            &[_]usize{ 4, 6, 7, 9 },
            &[_]usize{ 5, 7, 6, 8 },
            &[_]usize{ 5, 6, 7, 8 },
        }).sort(T, input),
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
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N16L46D10
        16 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
            &[_]usize{ 0, 6, 2, 4, 9, 15, 11, 13 },
            &[_]usize{ 4, 9, 6, 11 },
            &[_]usize{ 1, 9, 3, 11, 4, 12, 6, 14 },
            &[_]usize{ 0, 4, 1, 10, 2, 6, 3, 8, 5, 14, 7, 12, 9, 13, 11, 15 },
            &[_]usize{ 1, 12, 3, 14, 4, 7, 5, 6, 8, 11, 9, 10 },
            &[_]usize{ 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14 },
            &[_]usize{ 3, 5, 6, 8, 7, 9, 10, 12 },
            &[_]usize{ 5, 8, 7, 10 },
            &[_]usize{ 5, 7, 8, 10 },
        }).sort(T, input),
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
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N18L55D12
        18 => SortingNetwork([_]Layer{
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
        }).sort(T, input),
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
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N20L63D12
        20 => SortingNetwork([_]Layer{
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
        }).sort(T, input),
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
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N24L82D14
        24 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23 },
            &[_]usize{ 0, 2, 1, 3, 4, 6, 5, 7, 8, 10, 9, 11, 12, 14, 13, 15, 16, 18, 17, 19, 20, 22, 21, 23 },
            &[_]usize{ 0, 20, 1, 21, 2, 22, 3, 23, 4, 16, 5, 13, 6, 9, 7, 19, 8, 12, 10, 18, 11, 15, 14, 17 },
            &[_]usize{ 0, 8, 1, 16, 5, 10, 6, 14, 7, 22, 9, 17, 13, 18, 15, 23 },
            &[_]usize{ 2, 9, 3, 10, 4, 8, 7, 12, 11, 16, 13, 20, 14, 21, 15, 19 },
            &[_]usize{ 1, 7, 2, 5, 3, 14, 6, 13, 9, 20, 10, 17, 11, 12, 16, 22, 18, 21 },
            &[_]usize{ 3, 8, 5, 7, 10, 12, 11, 13, 15, 20, 16, 18 },
            &[_]usize{ 7, 13, 8, 11, 10, 16, 12, 15 },
            &[_]usize{ 5, 7, 9, 13, 10, 14, 16, 18 },
            &[_]usize{ 7, 11, 9, 10, 12, 16, 13, 14 },
            &[_]usize{ 10, 11, 12, 13 },
            &[_]usize{ 10, 12, 11, 13 },
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N25L85D16
        25 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23 },
            &[_]usize{ 0, 2, 1, 3, 4, 6, 5, 7, 8, 10, 9, 11, 12, 14, 13, 15, 16, 18, 17, 19, 20, 22, 21, 23 },
            &[_]usize{ 0, 4, 1, 5, 2, 6, 3, 7, 8, 12, 9, 13, 10, 14, 11, 15, 16, 20, 17, 21, 18, 22, 19, 23 },
            &[_]usize{ 0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15 },
            &[_]usize{ 3, 19, 5, 21, 6, 22, 7, 23, 8, 16, 9, 17, 10, 18, 12, 20 },
            &[_]usize{ 1, 12, 2, 9, 3, 5, 4, 10, 11, 21, 13, 22, 14, 19, 18, 20 },
            &[_]usize{ 9, 10, 11, 13 },
            &[_]usize{ 7, 13, 10, 12, 11, 14 },
            &[_]usize{ 5, 11, 10, 16, 12, 18 },
            &[_]usize{ 3, 12, 9, 16, 11, 20, 14, 18 },
            &[_]usize{ 5, 16, 6, 12, 7, 14, 11, 17 },
            &[_]usize{ 7, 16, 11, 24, 12, 17 },
            &[_]usize{ 7, 11, 16, 24 },
            &[_]usize{ 6, 11, 12, 16 },
            &[_]usize{ 11, 12 },
            &[_]usize{ 12, 16 },
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N48L228D22
        48 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47 },
            &[_]usize{ 0, 2, 1, 3, 4, 6, 5, 7, 8, 10, 9, 11, 12, 14, 13, 15, 16, 18, 17, 19, 20, 22, 21, 23, 24, 26, 25, 27, 28, 30, 29, 31, 32, 34, 33, 35, 36, 38, 37, 39, 40, 42, 41, 43, 44, 46, 45, 47 },
            &[_]usize{ 0, 4, 1, 5, 2, 6, 3, 7, 8, 12, 9, 13, 10, 14, 11, 15, 16, 20, 17, 21, 18, 22, 19, 23, 24, 28, 25, 29, 26, 30, 27, 31, 32, 36, 33, 37, 34, 38, 35, 39, 40, 44, 41, 45, 42, 46, 43, 47 },
            &[_]usize{ 0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15, 16, 24, 17, 25, 18, 26, 19, 27, 20, 28, 21, 29, 22, 30, 23, 31, 32, 40, 33, 41, 34, 42, 35, 43, 36, 44, 37, 45, 38, 46, 39, 47 },
            &[_]usize{ 0, 32, 1, 33, 2, 34, 3, 35, 4, 36, 5, 37, 6, 38, 7, 39, 8, 40, 9, 41, 10, 42, 11, 43, 12, 44, 13, 45, 14, 46, 15, 47, 20, 24, 21, 25, 22, 26, 23, 27 },
            &[_]usize{ 3, 17, 5, 40, 6, 25, 7, 42, 10, 18, 12, 21, 14, 23, 22, 41, 24, 33, 26, 35, 29, 37, 30, 44 },
            &[_]usize{ 1, 12, 3, 8, 4, 10, 5, 20, 6, 17, 13, 14, 18, 26, 21, 29, 27, 42, 30, 41, 33, 34, 35, 46, 37, 43, 39, 44 },
            &[_]usize{ 7, 26, 8, 36, 10, 24, 11, 39, 13, 33, 14, 34, 21, 40, 23, 37 },
            &[_]usize{ 7, 19, 8, 13, 9, 24, 11, 25, 18, 21, 22, 36, 23, 38, 26, 29, 28, 40, 34, 39 },
            &[_]usize{ 2, 22, 11, 30, 13, 16, 14, 21, 15, 29, 17, 36, 18, 32, 25, 45, 26, 33, 31, 34 },
            &[_]usize{ 9, 32, 11, 16, 12, 14, 15, 38, 31, 36, 33, 35 },
            &[_]usize{ 6, 32, 7, 12, 11, 22, 14, 20, 15, 41, 25, 36, 27, 33, 35, 40 },
            &[_]usize{ 12, 28, 14, 22, 19, 35, 20, 23, 24, 27, 25, 33 },
            &[_]usize{ 15, 23, 16, 22, 17, 20, 24, 32, 25, 31, 27, 30 },
            &[_]usize{ 12, 17, 15, 27, 16, 24, 19, 25, 20, 32, 22, 28, 23, 31, 30, 35 },
            &[_]usize{ 15, 19, 17, 24, 21, 25, 22, 26, 23, 30, 28, 32 },
            &[_]usize{ 19, 23, 20, 26, 21, 27, 24, 28 },
            &[_]usize{ 19, 21, 22, 24, 23, 25, 26, 28 },
            &[_]usize{ 19, 26, 20, 24, 21, 28, 23, 27 },
            &[_]usize{ 15, 24, 23, 32 },
            &[_]usize{ 21, 23, 24, 26 },
            &[_]usize{ 21, 24, 23, 26 },
        }).sort(T, input),
        // https://bertdobbelaere.github.io/median_networks.html#N49L231D25
        49 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47 },
            &[_]usize{ 0, 2, 1, 3, 4, 6, 5, 7, 8, 10, 9, 11, 12, 14, 13, 15, 16, 18, 17, 19, 20, 22, 21, 23, 24, 26, 25, 27, 28, 30, 29, 31, 32, 34, 33, 35, 36, 38, 37, 39, 40, 42, 41, 43, 44, 46, 45, 47 },
            &[_]usize{ 0, 4, 1, 5, 2, 6, 3, 7, 8, 12, 9, 13, 10, 14, 11, 15, 16, 20, 17, 21, 18, 22, 19, 23, 24, 28, 25, 29, 26, 30, 27, 31, 32, 36, 33, 37, 34, 38, 35, 39, 40, 44, 41, 45, 42, 46, 43, 47 },
            &[_]usize{ 0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15, 16, 24, 17, 25, 18, 26, 19, 27, 20, 28, 21, 29, 22, 30, 23, 31, 32, 40, 33, 41, 34, 42, 35, 43, 36, 44, 37, 45, 38, 46, 39, 47 },
            &[_]usize{ 0, 32, 1, 33, 2, 34, 3, 35, 4, 36, 5, 37, 6, 38, 7, 39, 8, 40, 9, 41, 10, 42, 11, 43, 12, 44, 13, 45, 14, 46, 15, 47, 20, 24, 21, 25, 22, 26, 23, 27 },
            &[_]usize{ 3, 17, 5, 40, 6, 25, 7, 42, 10, 18, 12, 21, 14, 23, 22, 41, 24, 33, 26, 35, 29, 37, 30, 44 },
            &[_]usize{ 1, 12, 3, 8, 4, 10, 5, 20, 6, 17, 13, 14, 18, 26, 21, 29, 27, 42, 30, 41, 33, 34, 35, 46, 37, 43, 39, 44 },
            &[_]usize{ 7, 26, 8, 36, 10, 24, 11, 39, 13, 33, 14, 34, 21, 40, 23, 37 },
            &[_]usize{ 7, 19, 8, 13, 9, 24, 11, 25, 18, 21, 22, 36, 23, 38, 26, 29, 28, 40, 34, 39 },
            &[_]usize{ 2, 22, 11, 30, 13, 16, 14, 21, 15, 29, 17, 36, 18, 32, 25, 45, 26, 33, 31, 34 },
            &[_]usize{ 9, 32, 11, 16, 12, 14, 15, 38, 31, 36, 33, 35 },
            &[_]usize{ 6, 32, 7, 12, 11, 22, 14, 20, 15, 41, 25, 36, 27, 33, 35, 40 },
            &[_]usize{ 12, 28, 14, 22, 19, 35, 20, 23, 24, 27, 25, 33 },
            &[_]usize{ 15, 23, 16, 22, 17, 20, 24, 32, 25, 31, 27, 30 },
            &[_]usize{ 12, 17, 15, 27, 16, 24, 19, 25, 20, 32, 22, 28, 23, 31, 30, 35 },
            &[_]usize{ 15, 19, 17, 24, 21, 25, 22, 26, 23, 30, 28, 32 },
            &[_]usize{ 19, 23, 20, 26, 21, 27, 24, 28 },
            &[_]usize{ 19, 21, 22, 24, 23, 25, 26, 28 },
            &[_]usize{ 19, 26, 20, 24, 21, 28, 23, 27 },
            &[_]usize{ 15, 24, 23, 32 },
            &[_]usize{ 21, 23, 24, 26 },
            &[_]usize{ 21, 24, 23, 26 },
            &[_]usize{ 23, 24 },
            &[_]usize{ 24, 48 },
            &[_]usize{ 23, 24 },
        }).sort(T, input),
        else => unreachable,
    }

    const UT = types.UnsignedArithmeticType(T);

    // Handle odd number of elements by returning the middle,
    // handle even number of elements by dividing elements on left
    // and right of middle by 2.
    return if (input.len % 2 == 1)
        input[input.len / 2]
    else if (types.isScalar(T))
        // Cast up to prevent over flow, then cast down to match expected output
        math.lossyCast(T, ((math.lossyCast(UT, input[(input.len / 2) - 1]) + input[input.len / 2]) / 2))
    else
        math.lossyCast(T, ((math.lossyCast(UT, input[(input.len / 2) - 1]) + input[input.len / 2]) / @as(T, @splat(2))));
}

test "Sorting Networks - Median" {
    var input1 = [_]u8{1};
    try std.testing.expectEqual(1, median(u8, &input1));

    var input2 = [_]u8{ 1, 3 };
    try std.testing.expectEqual(2, median(u8,  &input2));

    // Ensure we handle overflow
    var input2large = [_]u8{ 255, 255 };
    try std.testing.expectEqual(255, median(u8,  &input2large));

    var input3 = [_]u8{ 3, 1, 2 };
    try std.testing.expectEqual(2, median(u8,  &input3));

    var input4 = [_]u8{ 3, 1, 2, 4 };
    try std.testing.expectEqual(2, median(u8,  &input4));

    var input5 = [_]u8{ 3, 1, 5, 2, 4 };
    try std.testing.expectEqual(3, median(u8,  &input5));

    var input6 = [_]u8{ 3, 1, 5, 6, 2, 4 };
    try std.testing.expectEqual(3, median(u8,  &input6));

    var input7 = [_]u8{ 6, 3, 1, 5, 2, 4, 7 };
    try std.testing.expectEqual(4, median(u8,  &input7));

    var input8 = [_]u8{ 6, 3, 1, 5, 2, 4, 7, 8 };
    try std.testing.expectEqual(4, median(u8,  &input8));
    try std.testing.expectEqual(4, input8[input8.len / 2 - 1]);
    try std.testing.expectEqual(5, input8[input8.len / 2]);

    var input9 = [_]u8{ 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    try std.testing.expectEqual(5, median(u8,  &input9));

    var input10 = [_]u8{ 6, 8, 9, 3, 1, 5, 10, 2, 4, 7 };
    try std.testing.expectEqual(5, median(u8,  &input10));

    var input11 = [_]u8{ 10, 11, 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    try std.testing.expectEqual(6, median(u8,  &input11));

    var input12 = [_]u8{ 10, 11, 6, 8, 12, 9, 3, 1, 5, 2, 4, 7 };
    try std.testing.expectEqual(6, median(u8,  &input12));

    var input13 = [_]u8{ 12, 13, 10, 11, 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    try std.testing.expectEqual(7, median(u8,  &input13));

    var input14 = [_]u8{ 12, 13, 10, 11, 6, 8, 9, 3, 14, 1, 5, 2, 4, 7 };
    try std.testing.expectEqual(7, median(u8,  &input14));

    var input15 = [_]u8{ 14, 15, 12, 13, 10, 11, 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    try std.testing.expectEqual(8, median(u8,  &input15));

    var input16 = [_]u8{ 14, 15, 12, 13, 10, 11, 6, 8, 9, 3, 1, 16, 5, 2, 4, 7 };
    try std.testing.expectEqual(8, median(u8,  &input16));

    var input17 = [_]u8{ 16, 17, 14, 15, 12, 13, 10, 11, 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    try std.testing.expectEqual(9, median(u8,  &input17));

    var input18 = [_]u8{ 16, 17, 14, 15, 12, 13, 10, 11, 6, 8, 9, 3, 1, 18, 5, 2, 4, 7 };
    try std.testing.expectEqual(9, median(u8,  &input18));

    var input19 = [_]u8{ 18, 19, 16, 17, 14, 15, 12, 13, 10, 11, 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    try std.testing.expectEqual(10, median(u8,  &input19));

    var input20 = [_]u8{ 18, 19, 16, 17, 14, 15, 12, 13, 10, 11, 6, 8, 9, 3, 1, 20, 5, 2, 4, 7 };
    try std.testing.expectEqual(10, median(u8,  &input20));

    var input21 = [_]u8{ 20, 21, 18, 19, 16, 17, 14, 15, 12, 13, 10, 11, 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    try std.testing.expectEqual(11, median(u8,  &input21));

    var input25 = [_]u8{ 24, 25, 22, 23, 20, 21, 18, 19, 16, 17, 14, 15, 12, 13, 10, 11, 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    try std.testing.expectEqual(13, median(u8,  &input25));

    var input49 = [_]u8{ 48, 49, 46, 47, 44, 45, 42, 43, 40, 41, 38, 39, 36, 37, 34, 35, 32, 33, 30, 31, 28, 29, 26, 27, 24, 25, 22, 23, 20, 21, 18, 19, 16, 17, 14, 15, 12, 13, 10, 11, 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    try std.testing.expectEqual(25, median(u8,  &input49));
}

/// Computes the median of any 3 values.
/// Essentially just an inline sorting network.
pub fn median3(a: anytype, b: anytype, c: anytype) @TypeOf(a, b, c) {
    return @min(@max(@min(a, c), b), @max(a, c));
}

test median3 {
    try std.testing.expectEqual(3, median3(1, 3, 5));
    try std.testing.expectEqual(3, median3(3, 1, 5));
    try std.testing.expectEqual(3, median3(5, 3, 1));
    try std.testing.expectEqual(3, median3(1, 5, 3));
    try std.testing.expectEqual(3, median3(3, 5, 1));
    try std.testing.expectEqual(3, median3(5, 1, 3));
}

// Sorts input array in place using sorting networks.
//
// Wouldn't have been possible without the wonderful work of SorterHunter:
// https://bertdobbelaere.github.io/sorting_networks.html
pub fn sort(comptime T: type, comptime N: u8, input: *[N]T) void {
    const Layer = []const usize;
    switch (comptime N) {
        // https://bertdobbelaere.github.io/sorting_networks.html#N8L19D6
        8 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 2, 1, 3, 4, 6, 5, 7 },
            &[_]usize{ 0, 4, 1, 5, 2, 6, 3, 7 },
            &[_]usize{ 0, 1, 2, 3, 4, 5, 6, 7 },
            &[_]usize{ 2, 4, 3, 5 },
            &[_]usize{ 1, 4, 3, 6 },
            &[_]usize{ 1, 2, 3, 4, 5, 6 },
        }).sort(T, input),
        // https://bertdobbelaere.github.io/sorting_networks.html#N9L25D7
        9 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 3, 1, 7, 2, 5, 4, 8 },
            &[_]usize{ 0, 7, 2, 4, 3, 8, 5, 6 },
            &[_]usize{ 0, 2, 1, 3, 4, 5, 7, 8 },
            &[_]usize{ 1, 4, 3, 6, 5, 7 },
            &[_]usize{ 0, 1, 2, 4, 3, 5, 6, 8 },
            &[_]usize{ 2, 3, 4, 5, 6, 7 },
            &[_]usize{ 1, 2, 3, 4, 5, 6 },
        }).sort(T, input),
        // https://bertdobbelaere.github.io/sorting_networks.html#N25L130D15
        25 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23 },
            &[_]usize{ 0, 2, 1, 3, 4, 6, 5, 7, 8, 10, 9, 11, 12, 14, 13, 15, 16, 18, 17, 19, 21, 22, 23, 24 },
            &[_]usize{ 0, 4, 1, 5, 2, 6, 3, 7, 8, 12, 9, 13, 10, 14, 11, 15, 18, 21, 20, 23, 22, 24 },
            &[_]usize{ 0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15, 16, 20, 17, 22, 19, 24, 21, 23 },
            &[_]usize{ 1, 18, 3, 21, 5, 23, 6, 19, 11, 14, 15, 24 },
            &[_]usize{ 1, 16, 3, 17, 6, 9, 7, 11, 13, 19, 14, 23 },
            &[_]usize{ 0, 1, 2, 16, 3, 8, 7, 20, 10, 13, 11, 22, 15, 23 },
            &[_]usize{ 1, 2, 5, 10, 7, 18, 11, 21, 15, 20, 19, 22 },
            &[_]usize{ 4, 7, 5, 6, 9, 18, 10, 17, 11, 12, 13, 21, 14, 15, 19, 20, 22, 23 },
            &[_]usize{ 3, 4, 7, 8, 9, 10, 11, 16, 12, 17, 13, 18, 19, 21, 20, 22 },
            &[_]usize{ 1, 3, 2, 4, 5, 11, 6, 16, 7, 9, 8, 10, 12, 13, 14, 19, 15, 18 },
            &[_]usize{ 2, 3, 5, 7, 6, 9, 8, 11, 10, 16, 12, 14, 15, 17 },
            &[_]usize{ 3, 5, 4, 6, 7, 8, 9, 11, 10, 12, 13, 14, 15, 16, 17, 18 },
            &[_]usize{ 4, 7, 6, 8, 9, 10, 11, 12, 13, 15, 14, 16, 17, 19, 18, 21 },
            &[_]usize{ 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21 },
        }).sort(T, input),
        // https://bertdobbelaere.github.io/sorting_networks_extended.html#N49L365D21
        49 => SortingNetwork([_]Layer{
            &[_]usize{ 0, 8, 1, 7, 2, 6, 3, 11, 4, 10, 5, 9, 12, 20, 13, 19, 14, 18, 15, 23, 16, 22, 17, 21, 24, 32, 25, 31, 26, 30, 27, 35, 28, 34, 29, 33, 36, 48, 37, 46, 38, 45, 39, 43, 41, 47, 42, 44 },
            &[_]usize{ 0, 1, 2, 5, 3, 4, 6, 9, 7, 8, 10, 11, 12, 13, 14, 17, 15, 16, 18, 21, 19, 20, 22, 23, 24, 25, 26, 29, 27, 28, 30, 33, 31, 32, 34, 35, 37, 42, 38, 39, 40, 47, 43, 45, 44, 46 },
            &[_]usize{ 0, 2, 1, 6, 5, 10, 9, 11, 12, 14, 13, 18, 17, 22, 21, 23, 24, 26, 25, 30, 29, 34, 33, 35, 36, 40, 37, 38, 39, 42, 43, 44, 45, 46, 47, 48 },
            &[_]usize{ 0, 3, 1, 2, 4, 6, 5, 7, 8, 11, 9, 10, 12, 15, 13, 14, 16, 18, 17, 19, 20, 23, 21, 22, 24, 27, 25, 26, 28, 30, 29, 31, 32, 35, 33, 34, 40, 42, 41, 45, 44, 47, 46, 48 },
            &[_]usize{ 0, 24, 1, 4, 3, 5, 6, 8, 7, 10, 11, 23, 13, 16, 15, 17, 18, 20, 19, 22, 25, 28, 27, 29, 30, 32, 31, 34, 36, 41, 39, 44, 40, 43, 42, 47, 45, 46 },
            &[_]usize{ 1, 3, 2, 5, 6, 9, 8, 10, 13, 15, 14, 17, 18, 21, 20, 22, 25, 27, 26, 29, 30, 33, 32, 34, 36, 37, 38, 41, 42, 45, 43, 44, 46, 47 },
            &[_]usize{ 1, 13, 2, 3, 4, 5, 6, 7, 8, 9, 10, 22, 12, 36, 14, 15, 16, 17, 18, 19, 20, 21, 26, 27, 28, 29, 30, 31, 32, 33, 35, 47, 37, 39, 38, 40, 41, 42, 45, 46 },
            &[_]usize{ 0, 12, 2, 14, 4, 6, 5, 7, 9, 21, 11, 35, 16, 18, 17, 19, 23, 47, 24, 36, 28, 30, 29, 31, 34, 46, 37, 38, 39, 40, 41, 43, 42, 44 },
            &[_]usize{ 3, 4, 5, 6, 7, 8, 10, 34, 12, 24, 15, 16, 17, 18, 19, 20, 22, 46, 23, 35, 25, 37, 27, 28, 29, 30, 31, 32, 38, 39, 40, 41, 42, 43, 44, 45 },
            &[_]usize{ 1, 25, 3, 15, 4, 28, 5, 29, 6, 30, 7, 31, 8, 32, 13, 37, 19, 43, 20, 48, 22, 34, 26, 38, 33, 45, 39, 40, 41, 42 },
            &[_]usize{ 2, 26, 4, 40, 7, 19, 8, 20, 9, 33, 13, 25, 14, 38, 16, 28, 17, 41, 18, 42, 21, 45, 27, 39, 31, 43, 32, 48 },
            &[_]usize{ 3, 27, 5, 17, 6, 18, 9, 37, 10, 38, 14, 26, 15, 39, 19, 31, 20, 32, 21, 33, 28, 44, 29, 41, 30, 42, 35, 43, 36, 40 },
            &[_]usize{ 5, 13, 6, 14, 8, 28, 9, 25, 10, 26, 11, 39, 15, 27, 16, 36, 17, 29, 18, 30, 20, 40, 21, 37, 22, 38, 32, 44, 33, 41, 34, 42, 43, 46 },
            &[_]usize{ 4, 16, 7, 15, 8, 24, 9, 13, 10, 14, 11, 27, 17, 25, 18, 26, 21, 29, 22, 30, 23, 39, 28, 36, 32, 40, 33, 37, 34, 38, 42, 48 },
            &[_]usize{ 3, 9, 4, 12, 11, 15, 13, 17, 14, 18, 19, 27, 21, 25, 22, 26, 23, 31, 24, 28, 29, 33, 30, 34, 32, 36, 35, 39, 38, 44, 43, 48 },
            &[_]usize{ 1, 4, 3, 5, 7, 13, 8, 12, 11, 17, 15, 19, 16, 24, 20, 28, 23, 27, 30, 36, 31, 35, 34, 40, 39, 45 },
            &[_]usize{ 2, 8, 7, 9, 12, 16, 15, 21, 19, 25, 20, 24, 23, 29, 27, 33, 28, 32, 31, 37, 34, 36, 35, 41, 39, 42, 45, 48 },
            &[_]usize{ 2, 4, 6, 12, 10, 16, 14, 20, 18, 24, 19, 21, 22, 28, 23, 25, 26, 32, 29, 30, 31, 33, 35, 38, 37, 40, 39, 44, 43, 45, 46, 48 },
            &[_]usize{ 6, 8, 10, 12, 11, 14, 13, 16, 15, 20, 17, 18, 22, 24, 26, 28, 27, 32, 31, 34, 33, 36, 35, 37, 38, 40, 41, 44, 47, 48 },
            &[_]usize{ 3, 6, 5, 8, 7, 10, 9, 12, 11, 13, 14, 16, 15, 17, 18, 20, 19, 22, 21, 24, 23, 26, 25, 28, 27, 29, 30, 32, 33, 34, 35, 36, 37, 38, 39, 41, 42, 44 },
            &[_]usize{ 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 39, 40, 43, 44 },
        }).sort(T, input),
        else => unreachable,
    }
}

test "Sorting Networks - sort" {
    var input8 = [8]u8{ 6, 8, 3, 1, 5, 2, 4, 7 };
    sort(u8, input8.len, &input8);
    try std.testing.expectEqualDeep([_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 }, input8);

    var input9 = [9]u8{ 6, 8, 9, 3, 1, 5, 2, 4, 7 };
    sort(u8, input9.len, &input9);
    try std.testing.expectEqualDeep([_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, input9);

    var input25 = [25]u8{ 6, 8, 9, 3, 1, 5, 2, 4, 7, 11, 10, 12, 14, 13, 16, 15, 17, 18, 19, 20, 21, 24, 23, 22, 25 };
    sort(u8, input25.len, &input25);
    try std.testing.expectEqualDeep([_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25 }, input25);
}
