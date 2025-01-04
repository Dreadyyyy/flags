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

    AllocationErr,
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
                    .Pointer => break :blk if (tp == []const u8) str else {
                        @compileError("Flag of type " ++ @typeName(T) ++ " is not supported");
                    },
                    .Optional => |opt| tp = opt.child,
                    .ErrorUnion => |errun| tp = errun.payload,
                    else => @compileError("Flag of type " ++ @typeName(T) ++ " is not supported"),
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

pub const Parser = struct {
    map: std.StringHashMap(Flag),

    pub fn init(alloc: std.mem.Allocator) Parser {
        return Parser{ .map = std.StringHashMap(Flag).init(alloc) };
    }

    pub fn deinit(self: *Parser) void {
        self.map.deinit();
    }

    pub fn add(self: *Parser, ptr: anytype, flag: []const u8) FlagErr!void {
        const T = switch (@typeInfo(@TypeOf(ptr))) {
            .Pointer => |pointer| if (pointer.size == .One) pointer.child else {
                @compileError("Argument ptr must be a single item pointer, not a " ++ @typeName(@TypeOf(ptr)));
            },
            else => @compileError("Argument ptr must be a single item pointer, not a " ++ @typeName(@TypeOf(ptr))),
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

        self.map.put(flag, Flag{
            .has_param = has_param,
            .ptr = @ptrCast(ptr),
            .fromStr = fromStr(T),
        }) catch return FlagErr.AllocationErr;
    }

    pub fn parse(self: *const Parser, alloc: std.mem.Allocator) FlagErr!std.ArrayList([]const u8) {
        var iter = std.process.argsWithAllocator(alloc) catch return FlagErr.AllocationErr;
        defer iter.deinit();

        var pos_args = std.ArrayList([]const u8).init(alloc);
        errdefer pos_args.deinit();
        pos_args.append(iter.next().?) catch return FlagErr.AllocationErr;

        while (iter.next()) |arg| {
            if (std.mem.eql(u8, arg, "--")) break;
            if (arg.len > 0 and arg[0] != '-') {
                pos_args.append(arg) catch return FlagErr.AllocationErr;
                break;
            }

            const flag, var param = blk: {
                const delim = std.mem.indexOfScalar(u8, arg, '=') orelse break :blk .{ arg, null };
                break :blk .{ arg[0..delim], arg[delim + 1 ..] };
            };

            const f = self.map.get(flag) orelse return FlagErr.UnknownFlag;

            if (!f.has_param and param != null) return FlagErr.ParameterErr;

            if (f.has_param and param == null) {
                param = iter.next() orelse return FlagErr.ParameterErr;
                if (param.?.len != 0 and param.?[0] == '-') return FlagErr.ParameterErr;
            }

            try f.fromStr(f.ptr, param orelse "");
        }

        while (iter.next()) |arg| pos_args.append(arg) catch return FlagErr.AllocationErr;

        return pos_args;
    }
};
