const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
        .cpu_features_add = std.Target.arm.featureSet(&.{.vfp4d16sp}),
    });

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "MICROBIT",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/startup.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.setLinkerScript(b.path("microbit.ld"));
    exe.link_gc_sections = true;
    exe.entry = .{ .symbol_name = "Reset_Handler" };

    b.installArtifact(exe);

    // zig build flash
    const objcopy = exe.addObjCopy(.{ .format = .hex });
    const hex_step = b.addInstallBinFile(objcopy.getOutput(), "MICROBIT.hex");

    const flash = b.step("flash", "Build hex and copy to micro:bit");
    flash.dependOn(&hex_step.step);

    const cp = b.addSystemCommand(&.{ "cp", "zig-out/bin/MICROBIT.hex", "/media/rafael/MICROBIT/." });
    cp.step.dependOn(&hex_step.step);
    flash.dependOn(&cp.step);
}
