pub fn BitField(comptime T: type) type {
    return struct {
        val: *volatile T,

        const Self = @This();
        const bit_count = @bitSizeOf(T);

        pub fn init(addr: *volatile T) Self {
            addr.* = 0;
            return Self{ .val = addr };
        }

        pub fn initVal(addr: *volatile T, v: T) Self {
            addr.* = v;
            return Self{ .val = addr };
        }

        // Comptime bit index versions
        pub fn setComptime(self: *Self, comptime n: comptime_int, v: bool) void {
            comptime validateBit(n);
            if (v) self.onComptime(n) else self.offComptime(n);
        }

        pub fn onComptime(self: *Self, comptime n: comptime_int) void {
            comptime validateBit(n);
            self.val.* |= @as(T, 1) << n;
        }

        pub fn offComptime(self: *Self, comptime n: comptime_int) void {
            comptime validateBit(n);
            self.val.* &= ~(@as(T, 1) << n);
        }

        pub fn toggleComptime(self: *Self, comptime n: comptime_int) void {
            comptime validateBit(n);
            self.val.* ^= @as(T, 1) << n;
        }

        pub fn checkComptime(self: *Self, comptime n: comptime_int) bool {
            comptime validateBit(n);
            return (self.val.* >> n) & 1 != 0;
        }

        // Runtime bit index versions
        pub fn set(self: *Self, n: u8, v: bool) void {
            if (v) self.on(n) else self.off(n);
        }

        pub fn on(self: *Self, n: u8) void {
            self.val.* |= @as(T, 1) << @intCast(n);
        }

        pub fn off(self: *Self, n: u8) void {
            self.val.* &= ~(@as(T, 1) << @intCast(n));
        }

        pub fn toggle(self: *Self, n: u8) void {
            self.val.* ^= @as(T, 1) << @intCast(n);
        }

        pub fn check(self: *Self, n: u8) bool {
            return (self.val.* >> @intCast(n)) & 1 != 0;
        }

        pub fn clear(self: *Self) void {
            self.val.* = 0;
        }

        pub fn setAll(self: *Self, v: T) void {
            self.val.* = v;
        }

        fn validateBit(comptime n: comptime_int) void {
            if (n < 0 or n >= bit_count) {
                @compileError("bit index out of range");
            }
        }
    };
}
