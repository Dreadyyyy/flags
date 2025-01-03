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

    try testing.expectEqualDeep(b, true);
    try testing.expectEqualDeep(ni, 1);
    try testing.expectEqualDeep(nf, 1.23);
    try testing.expectEqualDeep(s, "bar");
    try testing.expectEqualDeep(idx, 7);
}
