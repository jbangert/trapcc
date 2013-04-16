harddisk.img: kernel.bin
	./buildhddimg.sh
kernel.bin: loader.o kernel.o linker.ld
	ld -T linker.ld -m elf_i386  -o $@ loader.o kernel.o 
loader.o: loader.S
	nasm -f elf32 -o $@ $<
kernel.o: sample.c
	gcc -c -std=c99 -m32 -o $@ $< -Wall -Wextra -nostdlib -fno-builtin -nostartfiles -nodefaultlibs -ggdb -fno-inline

clean:
	rm *.o *.bin *.img sample.c
sample.c : ../*.rb ../standalone.c *.rb
	(cat ../standalone.c; ruby sample_program_1.rb) > sample.c

