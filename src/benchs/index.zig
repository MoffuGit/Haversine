const reader = @import("reader.zig");
const noop = @import("noop_bottleneck.zig");
const branch = @import("branch_pred.zig");

test {
    _ = branch;
    // _ = noop;
    // _ = reader;
}
