const std = @import("std");
// Expose a version that's easily consumable throughout the project.
pub const version = std.SemanticVersion{ .major = 0, .minor = 3, .patch = 0 };
