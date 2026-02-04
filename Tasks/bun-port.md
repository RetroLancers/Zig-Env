# Bun Port Changes Summary

This branch contains modifications to `Zig-Env` to support integration into the Bun codebase as a replacement for its internal environment variable parser.

## Key Changes

### 1. Parser Options Extensions
- Added `support_export_prefix: bool`: Allows the `export ` keyword before keys (e.g., `export KEY=VALUE`).
- Added `support_colon_separator: bool`: Allows `:` as a key-value separator when followed by a space (e.g., `KEY: VALUE`).

### 2. Interpolation Enhancements
- **Default Values:** Added support for `${VAR:-DEFAULT}` syntax.
- **VariablePosition Update:** Added `default_value` field and `setDefaultValue` method to store extracted defaults during parsing.
- **External Lookup Support:** Updated the finalizer to accept an optional `LookupFn` and context. This allows `Zig-Env` to resolve variables against Bun's process environment and previously loaded files.

### 3. API Updates
- `parseStringWithOptions`, `parseFileWithOptions`, and `parseReaderWithOptions` now accept `lookup_fn` and `context` parameters.
- `readKey` now accepts `ParserOptions` to conditionally handle `export` and `:` prefixes/separators.

### 4. Integration Logic
- The `finalizer` now attempts internal lookup first, then external lookup via the provided function, and finally falls back to the `${VAR:-DEFAULT}` value if both fail.
