
OUT := zig-out/bin/MICROBIT
HEX := zig-out/bin/MICROBIT.hex

all: 
	zig build 

small:
	zig build -Doptimize=ReleaseSmall

clean: 
	rm -rf zig-out
	rm -rf .zig-cache

embed: 
	arm-none-eabi-objcopy -O ihex  $(OUT) $(HEX)
	cp $(HEX) /media/rafael/MICROBIT/.

