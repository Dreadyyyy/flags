// MIT License
//
// Copyright (c) 2025 Egor Losev
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

const std = @import("std");

pub const FlagErr = error{
    ParseErr,
    UnknownFlag,
    ParameterErr,
};

fn fromStr(comptime T: type) fn (*anyopaque, []const u8) FlagErr!void {
    return struct {
        fn func(ptr: *anyopaque, str: []const u8) FlagErr!void {
            const tptr: *T = @ptrCast(@alignCast(ptr));

            comptime var tp = T;
            tptr.* = blk: inline while (true) {
                switch (@typeInfo(tp)) {
                    .Bool => break :blk true,
                    .Int => break :blk std.fmt.parseInt(tp, str, 0) catch return FlagErr.ParseErr,
                    .Float => break :blk std.fmt.parseFloat(tp, str) catch return FlagErr.ParseErr,
                    .Pointer => |pointer| if (pointer.is_const and pointer.child == u8) break :blk str else @compileError("Flag type not supported"),
                    .Optional => |opt| tp = opt.child,
                    .ErrorUnion => |errun| tp = errun.payload,
                    inline else => @compileError("Flag type not supported"),
                }
            };
        }
    }.func;
}

const Flag = struct {
    has_param: bool,
    ptr: *anyopaque,
    fromStr: *const fn (*anyopaque, []const u8) FlagErr!void,
};

const Allocator = std.mem.Allocator;

pub const Parser = struct {
    map: std.StringHashMap(Flag),

    pub fn init(alloc: Allocator) Parser {
        return Parser{ .map = std.StringHashMap(Flag).init(alloc) };
    }

    pub fn deinit(self: *Parser) void {
        self.map.deinit();
    }

    pub fn add(self: *Parser, ptr: anytype, flag: []const u8) !void {
        const T = switch (@typeInfo(@TypeOf(ptr))) {
            .Pointer => |pointer| pointer.child,
            inline else => @compileError("Argument ptr must be a pointer"),
        };

        comptime var tp = T;
        const has_param = blk: inline while (true) {
            switch (@typeInfo(tp)) {
                .Bool => break :blk false,
                .Optional => |opt| tp = opt.child,
                .ErrorUnion => |errun| tp = errun.payload,
                inline else => break :blk true,
            }
        };

        try self.map.put(flag, Flag{ .has_param = has_param, .ptr = @ptrCast(ptr), .fromStr = fromStr(T) });
    }

    pub fn parse(self: *const Parser, argv: []const []const u8) FlagErr!usize {
        var curr: usize = 0;
        while (curr < argv.len) : (curr += 1) {
            if (std.mem.eql(u8, argv[curr], "--")) return curr + 1;
            if (argv[curr].len > 0 and argv[curr][0] != '-') return curr;

            const flag, var param = blk: {
                const delim = std.mem.indexOfScalar(u8, argv[curr], '=') orelse break :blk .{ argv[curr], null };
                break :blk .{ argv[curr][0..delim], argv[curr][delim + 1 ..] };
            };

            const f = self.map.get(flag) orelse return FlagErr.UnknownFlag;

            if (!f.has_param and param != null) return FlagErr.ParameterErr;

            if (f.has_param and param == null) {
                curr += 1;

                if (curr < argv.len and argv[curr].len != 0 and argv[curr][0] != '-') {
                    param = argv[curr];
                } else {
                    return FlagErr.ParameterErr;
                }
            }

            try f.fromStr(f.ptr, param orelse "");
        }

        return curr;
    }
};
