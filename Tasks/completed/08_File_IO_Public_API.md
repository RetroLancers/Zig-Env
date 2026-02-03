# Task 08: File I/O and Public API

## Objective
Implement file reading and design the public API for the library.

## Background
The C++ implementation uses libuv for file I/O. In Zig, we use `std.fs` which is simpler and more idiomatic.

## Functions to Implement

### 1. parseFile (`src/lib.zig`)
**Purpose**: High-level API to parse a .env file from disk  
**Signature**: 
```zig
pub fn parseFile(allocator: Allocator, path: []const u8) !StringHashMap([]const u8)
```

### 2. parseString (`src/lib.zig`)
**Purpose**: Parse .env content from a string  
**Signature**:
```zig
pub fn parseString(allocator: Allocator, content: []const u8) !StringHashMap([]const u8)
```

### 3. parseReader (`src/lib.zig`)
**Purpose**: Parse from any std.io.Reader  
**Signature**:
```zig
pub fn parseReader(allocator: Allocator, reader: anytype) !StringHashMap([]const u8)
```

## File Reading Approach

```zig
pub fn parseFile(allocator: Allocator, path: []const u8) !StringHashMap([]const u8) {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    
    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);
    
    return parseString(allocator, content);
}
```

## Public API Design

```zig
// Main entry points
pub const parse = parseString;
pub const parseFile = parseFile;

// Types exposed to users
pub const Env = StringHashMap([]const u8);

// Utilities
pub fn get(env: *const Env, key: []const u8) ?[]const u8;
pub fn getWithDefault(env: *const Env, key: []const u8, default: []const u8) []const u8;
```

## Checklist

- [ ] Create `src/lib.zig` (main public interface)
- [ ] Implement `parseFile`
- [ ] Implement `parseString`
- [ ] Implement `parseReader`
- [ ] Add helper functions (`get`, `getWithDefault`)
- [ ] Add tests for file reading
- [ ] Add tests for string parsing
- [ ] Create example usage in README
- [ ] Export public API from root module

## Dependencies
- Task 05 (Core Reading) - readPairs
- Task 06 (Finalization) - finalizeAllValues
- Task 07 (Memory) - cleanup functions
