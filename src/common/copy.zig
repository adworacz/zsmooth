const std = @import("std");

// TODO: Use these copy helpers in all filters.

pub fn copyFirstNLines(comptime T: type, noalias dstp: []T, noalias srcp: []const T, width: usize, stride: usize, comptime num_lines: u32) void {
    var row: u32 = 0;
    while (row < num_lines) : (row += 1) {
        const line = row * stride;
        const end = line + width;
        @memcpy(dstp[line..end], srcp[line..end]);
    }
}

test copyFirstNLines {
    const T = u8;
    const srcp = [_]T{
        1, 1, 1, //
        2, 2, 2, //
        3, 3, 3, //
    };

    var dstp = [_]T{
        0, 0, 0, //
        0, 0, 0, //
        0, 0, 0, //
    };

    copyFirstNLines(T, &dstp, &srcp, 3, 3, 2);

    try std.testing.expectEqualDeep([_]T{
        1, 1, 1, //
        2, 2, 2, //
        0, 0, 0, //
    }, dstp);
}

pub fn copyLastNLines(comptime T: type, noalias dstp: []T, noalias srcp: []const T, height: usize, width: usize, stride: usize, comptime num_lines: u32) void {
    var row = (height - num_lines);
    while (row < height) : (row += 1) {
        const line = row * stride;
        const end = line + width;
        @memcpy(dstp[line..end], srcp[line..end]);
    }
}

test copyLastNLines {
    const T = u8;
    const srcp = [_]T{
        1, 1, 1, //
        2, 2, 2, //
        3, 3, 3, //
    };

    var dstp = [_]T{
        0, 0, 0, //
        0, 0, 0, //
        0, 0, 0, //
    };

    copyLastNLines(T, &dstp, &srcp, 3, 3, 3, 2);

    try std.testing.expectEqualDeep([_]T{
        0, 0, 0, //
        2, 2, 2, //
        3, 3, 3, //
    }, dstp);
}
