const reader = @import("reader.zig");
const noop = @import("noop_bottleneck.zig");

test {
    _ = noop;
    // _ = reader;
}
