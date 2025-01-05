# Zig Command-Line Argument Parser

A lightweight and flexible command-line argument parser for the Zig programming language

## Installation

Flags is a single file library and the preferable way of using it is copying the contents of root.zig file into your project

## Usage

### Basic Example

```zig
const std = @import("std");
const Parser = @import("parser.zig").Parser;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var parser = Parser.init(allocator);
    defer parser.deinit();

    var verbose = false;
    try parser.add(&verbose, "--verbose");

    var count: i32 = 0;
    try parser.add(&count, "--count");

    var name: ?[]const u8 = null;
    try parser.add(&name, "--name");

    const pos_args = try parser.parse(allocator);
    defer pos_args.deinit();

    if (verbose) std.debug.print("Verbose mode enabled.\n", .{});
    std.debug.print("Count: {d}\n", .{count});
    if (name) |value| std.debug.print("Name: {s}\n", .{value});
    std.debug.print("Program name: {s}\n", .{pos_args.items[0]});
    for (pos_args.items[1..]) |arg| std.debug.print("Positional argument: {s}\n", .{arg});
}
```
