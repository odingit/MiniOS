# makefile

.PHONY: init run fs fsck clean
.IGNORE: init

MAKE = make -r
AS = nasm
CC = gcc
DEL = rm -f
QEMU = qemu
LD = ld
OBJCPY = objcopy
GDB = cgdb
IMG = qemu-img
MKFS = mkfs.minix
FSCK = fsck.minix
CFLAGS = -c -O0 -Wall -Werror -nostdinc -fno-builtin -fno-stack-protector -funsigned-char \
		 -finline-functions -finline-small-functions -findirect-inlining \
		 -finline-functions-called-once -Iinclude -m32 -ggdb -gstabs+ -fdump-rtl-expand
ROOTFS = bin/rootfs
OBJS = bin/loader.o bin/main.o bin/asm.o bin/vga.o bin/string.o

# default task
default: Makefile
	$(MAKE) bin/floppy.raw
	$(MAKE) bin/floppy.img

# create a 1.44MB floppy include kernel and bootsector
bin/floppy.raw: boot/floppy.asm bin/bootsect.bin bin/kernel 
	$(AS) -I ./bin/ -f bin -l lst/floppy.s $< -o $@ 
	
bin/floppy.img:
	$(IMG) convert -f raw -O qcow2 bin/floppy.raw bin/floppy.img

# bootsector
bin/bootsect.bin: boot/bootsect.asm 
	$(AS) -I ./boot/ -f bin -l lst/bootsect.s $< -o $@ 

bin/loader.o : src/kernel/loader.asm
	$(AS) -I ./boot/ -f elf32 -g -F stabs -l lst/loader.s $< -o $@ 

# link loader.o and c objfile 
# generate a symbol file(kernel.elf) and a flat binary kernel file(kernel)
bin/kernel: script/link.ld $(OBJS) 
	$(LD) -T$< -melf_i386 -static -o $@.elf $(OBJS) -M>lst/map.map
	$(OBJCPY) -O binary $@.elf $@

# compile c file in all directory
bin/%.o: src/*/%.c
	$(CC) $(CFLAGS) -c $^ -o $@  
	$(CC) $(CFLAGS) -S $^ -o lst/$*.s

#----------------------------------------

# init
init:
	mkdir lst
	mkdir bin
	mkdir $(ROOTFS)

# make a disk with minix v1 file system
fs: 
	$(DEL) bin/rootfs.img
	$(IMG) create -f raw bin/rootfs.raw 10M
	$(MKFS) bin/rootfs.raw -1 -n14
	sudo mount -o loop -t minix bin/rootfs.raw $(ROOTFS)
	mkdir $(ROOTFS)/bin
	mkdir $(ROOTFS)/share
	cp usr/logo.txt $(ROOTFS)/share
	sleep 1
	sudo umount $(ROOTFS)
	$(IMG) convert -f raw -O qcow2 bin/rootfs.raw bin/rootfs.img

# check root file system
fsck:
	$(FSCK) -fsl bin/rootfs.raw

# run with qemu
run:
	$(QEMU) -S -s -fda bin/floppy.img -hda bin/rootfs.img -boot a &
	sleep 1
	$(GDB) -x script/gdbinit

# clean the binary file
clean: 
	$(DEL) bin/*.lst 
	$(DEL) bin/*.o 
	$(DEL) bin/*.bin 
	$(DEL) bin/*.tmp 
	$(DEL) bin/kernel 
	$(DEL) bin/kernel.elf
	$(DEL) bin/floppy.img
	$(DEL) lst/*