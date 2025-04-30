# Compiler and tools
ASM = nasm
QEMU = qemu-system-x86_64
DD = dd

# Flags
ASMFLAGS = -f bin

# Targets
all: disk.img

boot.bin: BootLoader.asm
	$(ASM) $(ASMFLAGS) BootLoader.asm -o boot.bin

second.bin: SecondStage.asm
	$(ASM) $(ASMFLAGS) SecondStage.asm -o second.bin

disk.img: boot.bin second.bin
	# Create empty disk image (1MB)
	$(DD) if=/dev/zero of=disk.img bs=1024 count=1024
	# Write boot sector to first sector
	$(DD) if=boot.bin of=disk.img conv=notrunc
	# Write second stage to second sector
	$(DD) if=second.bin of=disk.img conv=notrunc bs=512 seek=1
	# Show file sizes
	ls -l boot.bin second.bin

run: disk.img
	$(QEMU) -drive format=raw,file=disk.img -monitor stdio

clean:
	rm -f boot.bin second.bin disk.img

.PHONY: all run clean
