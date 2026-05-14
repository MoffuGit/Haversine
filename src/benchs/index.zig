const reader = @import("reader.zig");
const noop = @import("noop_bottleneck.zig");
const branch = @import("branch_pred.zig");
const ports = @import("ports.zig");

test {
    _ = ports;
    // _ = branch;
    // _ = noop;
    // _ = reader;
}
