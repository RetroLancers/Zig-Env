const std = @import("std");
const testing = std.testing;

pub const EnvStream = struct {
    data: []const u8,
    index: usize,
    length: usize,
    is_good: bool,

    pub fn init(data: []const u8) EnvStream {
        return EnvStream{
            .data = data,
            .index = 0,
            .length = data.len,
            .is_good = true,
        };
    }

    // Read next char and advance (return null on EOF)
    pub fn get(self: *EnvStream) ?u8 {
        if (!self.is_good or self.index >= self.length) {
            self.is_good = false;
            return null;
        }
        
        const char = self.data[self.index];
        self.index += 1;
        return char;
    }

    // Check if stream is valid
    pub fn good(self: EnvStream) bool {
        return self.is_good;
    }

    // Check if end of stream
    pub fn eof(self: EnvStream) bool {
        return self.index >= self.length;
    }
};

test "EnvStream basic reading" {
    const data = "test";
    var stream = EnvStream.init(data);
    
    try testing.expect(stream.good());
    try testing.expect(!stream.eof());
    
    try testing.expectEqual(@as(?u8, 't'), stream.get());
    try testing.expectEqual(@as(?u8, 'e'), stream.get());
    try testing.expectEqual(@as(?u8, 's'), stream.get());
    try testing.expectEqual(@as(?u8, 't'), stream.get());
    
    try testing.expect(stream.eof());
    try testing.expectEqual(@as(?u8, null), stream.get());
    try testing.expect(!stream.good());
}

test "EnvStream empty stream" {
    const data = "";
    var stream = EnvStream.init(data);
    
    try testing.expect(stream.eof());
    try testing.expect(stream.good()); // Good initially, just empty
    
    try testing.expectEqual(@as(?u8, null), stream.get());
    try testing.expect(!stream.good()); // Not good after trying to read past EOF
}

test "EnvStream state tracking" {
    const data = "a";
    var stream = EnvStream.init(data);
    
    try testing.expect(stream.good());
    _ = stream.get();
    try testing.expect(stream.good()); // Still good after reading last char
    try testing.expect(stream.eof()); // But at EOF
    
    _ = stream.get(); // Read past EOF
    try testing.expect(!stream.good()); // Now bad
}
