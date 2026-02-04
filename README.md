# ⚡ Zig-Env

**Zig-Env** is a high-performance, memory-efficient `.env` (dotenv) parser for the Zig programming language. Originally converted from the feature-rich [cppnv](https://github.com/RetroLancers/cppnv) project, it provides a robust and industrial-grade solution for managing environment variables.

[![Zig](https://img.shields.io/badge/Zig-0.15.2-orange.svg)](https://ziglang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 🚀 Key Features

*   ✅ **Standard Dotenv Support** - Full compatibility with standard `KEY=VALUE` syntax.
*   ✅ **Advanced Interpolation** - Support for `${VAR}` and `$VAR` (opt-in) with recursive resolution and circular dependency detection.
*   ✅ **Multi-Quote Support**:
    *   **Single Quotes** (`'...'`) - Literal strings, no interpolation or escapes.
    *   **Double Quotes** (`"..."`) - Interpolation + escape sequences (`\n`, `\t`, etc.).
    *   **Backticks** (`` `...` ``) - Behaves like double quotes.
*   ✅ **Heredocs & Multi-line Support**:
    *   Triple quotes (`"""..."""` or `'''...'''`).
    *   Bash-style multi-line support for single and double quotes.
*   ✅ **Windows & Unix Compatibility** - Transparent handling of `\r\n` and `\n` line endings.
*   ✅ **Zero-Allocation Focus** - Uses a custom `ReusableBuffer` and pre-scanning heatmaps to reduce allocations by **60-80%** compared to naive parsers.
*   ✅ **Order-Independent Variables** - Variables can reference other variables defined later in the file.
*   ✅ **Robust Error Handling** - Explicit error unions for all parsing operations.

---

## ⚡ Performance

Zig-Env is built for speed and efficiency. By utilizing a **Pre-Scanning** pass, the parser calculates optimal buffer sizes before allocation, significantly reducing memory fragmentation.

| Feature | Naive Parser | Zig-Env |
| :--- | :--- | :--- |
| **Allocations** | High (per key/value) | **Minimal** (pooled/pre-sized) |
| **Memory Reuse** | Low | **High** (ReusableBuffer) |
| **Parsing Speed** | Average | **Blazing Fast** |

---

## 📦 Installation

Add `zigenv` to your `build.zig.zon`:

```zig
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .zigenv = .{
            .url = "https://github.com/RetroLancers/Zig-Env/archive/refs/heads/main.tar.gz",
            // .hash = "...", // Add hash after first build
        },
    },
    .paths = .{ "" },
}
```

Then in your `build.zig`:

```zig
const zigenv = b.dependency("zigenv", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zigenv", zigenv.module("zigenv"));
```

---

## 📖 Quick Start

```zig
const std = @import("std");
const zigenv = @import("zigenv");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse from a string
    const content = 
        \\PORT=8080
        \\DOMAIN=example.com
        \\BASE_URL=https://${DOMAIN}:${PORT}
        \\API_KEY="""
        \\  very-long-
        \\  secret-key
        \\"""
    ;

    var env = try zigenv.parseString(allocator, content);
    defer env.deinit();

    // Access values
    if (env.get("BASE_URL")) |url| {
        std.debug.print("Full URL: {s}\n", .{url});
        // Returns: https://example.com:8080
    }

    // With Default
    const debug = env.getWithDefault("DEBUG", "false");
    std.debug.print("Debug: {s}\n", .{debug});
}
```

### Advanced Usage (Parser Options)

You can enable bash-style compatibility (e.g., braceless `$VAR` support) using `ParserOptions`:

```zig
var options = zigenv.ParserOptions.bashCompatible();
var env = try zigenv.parseFileWithOptions(allocator, ".env", options);
defer env.deinit();
```

---

## 📂 Project Structure

```text
Zig-Env/
├── src/                # Core implementation
│   ├── buffer/         # Optimized memory & buffer management
│   ├── data/           # Core data structures (Env, EnvPair, Options)
│   ├── interpolation/  # Variable resolution & finalization
│   ├── parser/         # State-machine based parsing logic
│   └── root.zig        # Module entry point
├── tests/              # Extensive test suite (150+ cases)
├── benchmarks/         # Performance & allocation benchmarking
└── Tasks/              # Task tracking and development history
```

---

## 🛠 Building & Testing

```bash
# Run all tests
zig build test

# Run benchmarks
zig build bench

# Generate documentation
zig build docs
```

---

## 📜 License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

*Note: This project is dedicated to providing high-quality tools for the Zig community.*
