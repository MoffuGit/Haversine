const reader = @import("reader.zig");
const noop = @import("noop_bottleneck.zig");
const branch = @import("branch_pred.zig");
const read_ports = @import("read_ports.zig");
const write_ports = @import("write_ports.zig");

test {
    _ = write_ports;
    // _ = read_ports;
    // _ = branch;
    // _ = noop;
    // _ = reader;
}
