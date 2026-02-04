# Task: Integrate Zig-Env with Bun's Ecosystem

## Problem Statement
Bun's internal environment variable parser (`bun/src/env_loader.zig`) currently fails on certain complex `.env` files. While `Zig-Env` is more robust and handles heredocs and advanced escaping, it lacks support for several Bun-specific syntax features and its interpolation mechanism is restricted to local file scope.

## Objectives
- [ ] Extend `ParserOptions` to support Bun-specific syntax (`export` prefix and `:` separator).
- [ ] Modify `readKey` to handle optional `export` keywords and `:` as a key-value separator.
- [ ] Refactor interpolation finalization to support external lookups (e.g., process environment).
- [ ] Provide a mapping layer between `Zig-Env`'s internal data structures and Bun's `DotEnv.Map`.

## Proposed Changes

### 1. Parser Options (src/data/parser_options.zig)
Add flags to control the new syntax features:
```zig
pub const ParserOptions = struct {
    // ... existing options ...
    support_export_prefix: bool = false,
    support_colon_separator: bool = false,
};
```

### 2. Key Parsing (src/parser/read_key.zig)
Update `readKey` to:
- Detect and skip the `export` keyword if `support_export_prefix` is enabled.
- Recognize `:` as a separator if it is followed by a space and `support_colon_separator` is enabled.

### 3. Interpolation Finalizer (src/interpolation/finalizer.zig)
Update `finalizeValue` to accept an optional lookup callback:
```zig
pub const LookupFn = *const fn (key: []const u8) ?[]const u8;

pub fn finalizeValue(
    allocator: std.mem.Allocator, 
    pair: *EnvPair, 
    pairs: *std.ArrayListUnmanaged(EnvPair),
    external_lookup: ?LookupFn
) !FinalizeResult;
```
This allows resolving `${VAR}` against Bun's global environment map.

### 4. Bun Integration (src/lib.zig)
Add a specialized entry point for Bun that simplifies the conversion to Bun's `Map` type, ensuring case-insensitivity rules on Windows are respected.

## Success Criteria
- [ ] All `Zig-Env` tests pass.
- [ ] New tests for `export` and `:` syntax pass.
- [ ] Interpolation correctly resolves variables from an external lookup source.
- [ ] The parser can handle unquoted values with trailing comments correctly when the Bun compatibility flags are set.
