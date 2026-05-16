const reader = @import("reader.zig");
const reader_simd = @import("reader_simd.zig");
const noop = @import("noop_bottleneck.zig");
const branch = @import("branch_pred.zig");
const read_ports = @import("read_ports.zig");
const write_ports = @import("write_ports.zig");
const cache = @import("cache.zig");

test {
    // _ = cache;
    // _ = read_ports;
    // _ = reader_simd;
    // _ = write_ports;
    // _ = branch;
    // _ = noop;
    _ = reader;
}
