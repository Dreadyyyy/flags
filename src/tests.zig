const std = @import("std");
const testing = std.testing;
const Parser = @import("root.zig").Parser;

test "test parser" {
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();

    var b: bool = false;
    try parser.addBool(&b, "-b");

    var ni: u8 = 0;
    try parser.addNumeric(@TypeOf(ni), &ni, "-ni");

    var nf: f32 = 0;
    try parser.addNumeric(@TypeOf(nf), &nf, "-nf");

    var s: []const u8 = "";
    try parser.addStr(&s, "-s");

    const argv = [_][]const u8{ "-b", "-ni=1", "-nf", "1.23", "-s", "bar", "--", "-foo" };
    const idx = try parser.parse(&argv);

    try testing.expect(b == true);
    try testing.expect(ni == 1);
    try testing.expect(nf == 1.23);
    try testing.expect(std.mem.eql(u8, s, "bar"));
    try testing.expect(idx == 7);
}
