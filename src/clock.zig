const CLOCK_BASE: u32 = 0x40000000;
const TASKS_HFCLKSTART: u32 = 0x000;
const EVENTS_HFCLKSTARTED: u32 = 0x100;

pub fn startHFCLK() void {
	const event = @as(*volatile u32, @ptrFromInt(CLOCK_BASE + EVENTS_HFCLKSTARTED));
	const task = @as(*volatile u32, @ptrFromInt(CLOCK_BASE + TASKS_HFCLKSTART));

	event.* = 0;
	task.* = 1;
	while (event.* == 0) {}
}
