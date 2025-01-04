const std = @import("std");
const testing = std.testing;

const Parser = @import("root.zig").Parser;
const FlagErr = @import("root.zig").FlagErr;

test "test parser standard types" {
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();

    var b: bool = false;
    try parser.add(&b, "-b");

    var ni: u8 = 0;
    try parser.add(&ni, "-ni");

    var nf: f32 = 0;
    try parser.add(&nf, "-nf");

    var s: []const u8 = "";
    try parser.add(&s, "-s");

    // Mock command line arguments
    const argv = [_][*:0]const u8{ "./out", "-b", "-ni=1", "-nf", "1.23", "-s", "bar", "--", "-foo" };
    std.os.argv.len = argv.len;
    std.os.argv.ptr = @ptrFromInt(@intFromPtr(&argv));

    const pos_args = try parser.parse(testing.allocator);
    defer pos_args.deinit();

    try testing.expectEqualDeep(b, true);
    try testing.expectEqualDeep(ni, 1);
    try testing.expectEqualDeep(nf, 1.23);
    try testing.expectEqualDeep(s, "bar");

    try testing.expectEqualDeep(pos_args.items.len, 2);
    try testing.expectEqualDeep(pos_args.items[0], "./out");
    try testing.expectEqualDeep(pos_args.items[1], "-foo");
}

test "test parser union types" {
    const SomeErr = error{
        Err,
    };

    var parser = Parser.init(testing.allocator);
    defer parser.deinit();

    var b: ?bool = null;
    try parser.add(&b, "-b");

    var ni: SomeErr!u8 = SomeErr.Err;
    try parser.add(&ni, "-ni");

    var nf: ?f32 = null;
    try parser.add(&nf, "-nf");

    var s: SomeErr![]const u8 = SomeErr.Err;
    try parser.add(&s, "-s");

    // Mock command line arguments
    const argv = [_][*:0]const u8{ "./out", "-b", "-ni=1", "-nf", "1.23", "-s", "bar", "--", "-foo" };
    std.os.argv.len = argv.len;
    std.os.argv.ptr = @ptrFromInt(@intFromPtr(&argv));

    const pos_args = try parser.parse(testing.allocator);
    defer pos_args.deinit();

    try testing.expectEqualDeep(b, true);
    try testing.expectEqualDeep(ni, 1);
    try testing.expectEqualDeep(nf, 1.23);
    try testing.expectEqualDeep(s, "bar");

    try testing.expectEqualDeep(pos_args.items.len, 2);
    try testing.expectEqualDeep(pos_args.items[0], "./out");
    try testing.expectEqualDeep(pos_args.items[1], "-foo");
}

test "test errorrs" {
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();

    var b: bool = false;
    try parser.add(&b, "-b");

    // Mock command line arguments
    const argv = [_][*:0]const u8{ "./out", "-b=true", "--", "-foo" };
    std.os.argv.len = argv.len;
    std.os.argv.ptr = @ptrFromInt(@intFromPtr(&argv));

    try testing.expectError(FlagErr.ParameterErr, parser.parse(testing.allocator));
}
