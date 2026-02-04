# Replacing Bun's Environment Variable Parser with Zig-Env

## Current State
Bun's environment variable parser is implemented in `bun/src/env_loader.zig`. It handles:
- Basic `KEY=VALUE` pairs.
- Shell-style `export KEY=VALUE`.
- Alternative `KEY: VALUE` syntax (if followed by a space).
- Quoting with `'`, `"`, and `` ` ``.
- Simple interpolation `${VAR}` and `${VAR:-DEFAULT}`.
- Case-insensitivity on Windows.

The current parser is known to fail on certain complex `.env` files, likely due to limited support for multiline values, heredocs, and advanced escaping.

## Zig-Env Advantages
`Zig-Env` offers a more robust and full-featured parser:
- **Multiline Support:** Handles heredocs (`"""`) and multi-line quoted strings.
- **Robust Quoting/Escaping:** Better handling of nested quotes and escape sequences.
- **Performance:** Includes a pre-scanner to optimize buffer allocations.
- **Correct Interpolation:** Handles recursive and complex interpolation patterns.

## Replacement Strategy

### 1. Integration
Import `Zig-Env` into the Bun codebase. Since Bun bundles its dependencies, the `Zig-Env/src` directory should be integrated into `bun/src/env/`.

### 2. Adaptation Layer
Since `Zig-Env`'s parser doesn't natively support some Bun-specific features, a wrapper or modifications will be needed:

- **`export` Prefix:** Modify `Zig-Env`'s `readKey` to optionally skip the `export` keyword.
- **`:` Separator:** Modify `Zig-Env`'s `readKey` to support `:` as a key-value separator, matching Bun's logic (requires checking for a following space).
- **Environment Mapping:** `Zig-Env` returns a list of `EnvPair` or a `StringHashMap`. These must be converted to Bun's `Map` (which uses `HashTableValue { value: string, conditional: bool }`).
- **Case-Insensitivity:** Ensure keys are handled case-insensitively on Windows, matching Bun's `CaseInsensitiveASCIIStringArrayHashMap`.

### 3. Resolving Interpolation
`Zig-Env`'s `finalizeValue` resolves interpolations using only the pairs found in the current file. Bun's parser resolves against the entire `Map` (which includes process environment variables).

**Change needed:** Update `Zig-Env`'s finalizer to accept a lookup function or a reference to Bun's `Map` so it can resolve variables from the process environment and previously loaded files.

### 4. Implementation Steps in `env_loader.zig`
In `Loader.loadEnvFile` and `Loader.loadEnvFileDynamic`:
1. Read file content into a buffer (already done).
2. Call `zig_env.parseStringWithOptions(this.allocator, content, options)`.
3. For each pair in the result:
   ```zig
   const entry = try this.map.map.getOrPut(pair.key);
   if (entry.found_existing) {
       if (entry.index < count) {
           if (!override) continue;
       } else {
           this.allocator.free(entry.value_ptr.value);
       }
   }
   entry.value_ptr.* = .{
       .value = try this.allocator.dupe(u8, pair.value),
       .conditional = false,
   };
   ```
4. If expansion is enabled, perform a final pass to resolve `${VAR}` using the integrated finalizer.

## Proposed Changes to `Zig-Env`
To make the transition smoother, `Zig-Env` should be extended with:
- `ParserOptions.support_export_prefix: bool`
- `ParserOptions.support_colon_separator: bool`
- A way to provide an external lookup map for interpolation.
