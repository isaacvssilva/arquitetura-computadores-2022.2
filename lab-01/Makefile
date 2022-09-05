CROSS_COMPILE ?= arm-linux-gnueabihf-

all: folder compiler copy

compiler: src/startup.s 
	$(CROSS_COMPILE)as src/startup.s -o obj/startup.o
	$(CROSS_COMPILE)objcopy obj/startup.o bin/startup.bin -O binary
	$(CROSS_COMPILE)objdump -D -b binary -marm bin/startup.bin > startup.lst

folder: 
	mkdir -p bin obj

copy:
	cp bin/startup.bin /tftpboot/

clean:
	rm obj/*.o bin/*.bin -rf obj/ bin/ *.lst
