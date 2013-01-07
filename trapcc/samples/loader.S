;;; Based heavily on http://wiki.osdev.org/Bare_Bones#kernel.c
global loader
extern	kmain
extern do_page_fault
global magic
global	mbd
global stack
global asmSetGDTR
global asmSetIDTR
global asm_pagefault
global asm_genericfaults
extern do_generic_fault
	; setting up the Multiboot header - see GRUB docs for details
MODULEALIGN equ  1<<0                   ; align loaded modules on page boundaries
MEMINFO     equ  1<<1                   ; provide memory map
LOADFIXED   equ  1<<16
FLAGS       equ  MODULEALIGN | MEMINFO ; this is the Multiboot 'flag' field
MAGIC       equ  0x1BADB002             ; 'magic number' lets bootloader find the header
CHECKSUM    equ -(MAGIC + FLAGS)        ; checksum required


	
section .text
bits 32
align 4
    dd MAGIC
    dd FLAGS
    dd CHECKSUM
 
; reserve initial kernel stack space
STACKSIZE equ 0x4000                    ; that's 16k.
 
loader:
    mov  esp, stack + STACKSIZE         ; set up the stack
    mov  [magic], eax                   ; Multiboot magic number
    mov  [mbd], ebx                     ; Multiboot info structure

    call kmain                          ; call kernel proper
 
    cli
.hang:
    hlt                                 ; halt machine should kernel return
    jmp  .hang
 
asmSetIDTR:
   MOV   EAX, [esp + 4]
   MOV   [gdtr + 2], EAX
   MOV   AX, [ESP + 8]
   MOV   [gdtr], AX
   LIDT  [gdtr]
   RET	
asmSetGDTR:
   MOV   EAX, [esp + 4]
   MOV   [gdtr + 2], EAX
   MOV   AX, [ESP + 8]
   MOV   [gdtr], AX
   LGDT  [gdtr]
   ; Reload CS register containing code selector:
   JMP   0x08:reload_CS ; 0x08 points at the new code selector
reload_CS:
   ; Reload data segment registers:
   MOV   AX, 0x10 ; 0x10 points at the new data selector
   MOV   DS, AX
   MOV   ES, AX
   MOV   FS, AX
   MOV   GS, AX
   MOV   SS, AX
   MOV   AX, 0x18
   LTR 	 AX
   RET

section .data 
	DD 0xDEADBEEF
gdtr:	DW 0 ; For limit storage
	DD 0 ; For base storage
	
section .bss
align 4
stack: resb STACKSIZE                   ; reserve 16k stack on a doubleword boundary
magic: resd 1
mbd:   resd 1
