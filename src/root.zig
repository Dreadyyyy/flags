const std = @import("std");

const FlagErr = error{
    ParseErr,
    UnknownFlag,
};

fn fromStr(comptime T: type) fn (*anyopaque, []const u8) FlagErr!void {
    return struct {
        fn func(ptr: *anyopaque, str: []const u8) FlagErr!void {
            const tptr: *T = @ptrCast(@alignCast(ptr));

            tptr.* = switch (@typeInfo(T)) {
                .bool => true,
                .int => std.fmt.parseInt(T, str, 0) catch return FlagErr.ParseErr,
                .float => std.fmt.parseFloat(T, str) catch return FlagErr.ParseErr,
                .pointer => |pointer| if (pointer.is_const and pointer.child == u8) str else unreachable,
                inline else => unreachable,
            };
        }
    }.func;
}

const Flag = struct {
    has_arg: bool,
    ptr: *anyopaque,
    fromStr: *const fn (*anyopaque, []const u8) FlagErr!void,
};

const Allocator = std.mem.Allocator;

const Parser = struct {
    map: std.StringHashMap(Flag),

    pub fn init(alloc: Allocator) Parser {
        return Parser{ .map = std.StringHashMap(Flag).init(alloc) };
    }

    pub fn deinit(self: *Parser) void {
        self.map.deinit();
    }

    pub fn addBool(self: *Parser, ptr: *bool, flag: []const u8) !void {
        try self.map.put(flag, Flag{ .has_arg = false, .ptr = ptr, .fromStr = fromStr(bool) });
    }

    pub fn addNumeric(self: *Parser, comptime T: type, ptr: *T, flag: []const u8) !void {
        try self.map.put(flag, Flag{ .has_arg = true, .ptr = ptr, .fromStr = fromStr(T) });
    }

    pub fn addStr(self: *Parser, ptr: *[]const u8, flag: []const u8) !void {
        try self.map.put(flag, Flag{ .has_arg = true, .ptr = @ptrCast(ptr), .fromStr = fromStr([]const u8) });
    }
};

const testing = std.testing;

test "test adding flags" {
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();

    var b: bool = false;
    try parser.addBool(&b, "b");

    var ni: u8 = 0;
    try parser.addNumeric(@TypeOf(ni), &ni, "ni");

    var nf: f32 = 0;
    try parser.addNumeric(@TypeOf(nf), &nf, "nf");

    var s: []const u8 = "";
    try parser.addStr(&s, "s");

    try testing.expect(parser.map.count() == 4);
}
