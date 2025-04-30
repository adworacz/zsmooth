const std = @import("std");

/// Convience funtion for writing strings / error messages that we pass back to
/// the vapoursynth C API.
///
/// Note that passing these strings back to Vapoursynth effectively means that
/// we're going to *leak memory when the program exits, but there's nothing we
/// can do about that due to the realities of the C interop.
pub fn printf(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) [:0]const u8 {
    return std.fmt.allocPrintZ(allocator, fmt, args) catch "Out of memory occurred while writing string.";
}

// TODO: Debug this test, seems to be freeing less memory than was allocated.
// test printf {
//     const msg = printf(std.testing.allocator, "Hello {s}", .{"world"});
//     defer std.testing.allocator.free(msg);
//
//     try std.testing.expectEqualStrings("Hello world", msg);
// }
