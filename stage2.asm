; stage2.asm  -> Loader (link/assemble as raw binary). org must match load addr 0x8000
bits 16
org 0x8000

start16:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x9000        ; small stack in real mode

    ; simple message showing we entered stage2
    mov si, s2msg
    call print_string

    ; prepare GDT and switch to protected mode
    ; we use labels in this file only
    lgdt [gdt_descriptor16]

    ; enable protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; far jump to 32-bit entry (selector 0x08)
    jmp 0x08:pm32_start

; print_string (real mode)
print_string:
    mov ah, 0x0E
.nexts:
    lodsb
    cmp al, 0
    je .dsdone
    int 0x10
    jmp .nexts
.dsdone:
    ret

s2msg db "Stage2: loaded at 0x8000 - switching to protected mode...",0

; -------------------------
; GDT (used from real mode before lgdt)
; -------------------------
gdt_start16:
    dq 0x0000000000000000
    dq 0x00CF9A000000FFFF   ; code seg: base=0 limit=4G, exec/read
    dq 0x00CF92000000FFFF   ; data seg: base=0 limit=4G, read/write
gdt_end16:

gdt_descriptor16:
    dw gdt_end16 - gdt_start16 - 1
    dd gdt_start16

; ============= 32-bit code ====================
bits 32
pm32_start:
    ; load data selector
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000

    ; now in protected mode: print message by BIOS won't work (int 0x10 is not available),
    ; but we keep it simple: use a tiny VGA write via video memory (optional)
    ; We'll just loop/halt to show success

pm32_ok_msg:
    ; (optional) write simple text to VGA memory at 0xB8000
    mov edi, 0xB8000
    mov ebx, 0
    mov al, 'P'
    mov ah, 0x07
    mov [edi], ax

    ; Safe HLT loop in protected mode
pm32_loop:
    jmp stage2_32

; ===============================
; stage2.asm – Stage 2 Loader
; 32-bit Protected Mode → 64-bit
; ===============================

bits 32
global stage2_32

section .text

stage2_32:

    ; ------------- Paging vorbereiten -------------

    ; PML4 bei 0x1000
    ; PDPT bei 0x2000
    ; PD bei  0x3000

    mov eax, 0x1000
    mov cr3, eax      ; CR3 = PML4 Base

    ; PML4[0] → PDPT
    mov dword [0x1000], 0x2003      ; Present | RW | Addr

    ; PDPT[0] → PD
    mov dword [0x2000], 0x3003      ; Present | RW | Addr

    ; PD[0] → 2 MB Identity Mapping
    mov dword [0x3000], 0x00000083  ; Present | RW | PS (2MB page)

    ; Zero out the rest
    mov ecx, 512
    mov edi, 0x1000
zero_tables:
    mov dword [edi], 0
    add edi, 4
    loop zero_tables

    ; Restore entries
    mov dword [0x1000], 0x2003
    mov dword [0x2000], 0x3003
    mov dword [0x3000], 0x00000083

    ; ------------- PAE + Long Mode aktivieren -------------

    ; CR4.PAE = 1
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; EFER.LME = 1
    mov ecx, 0xC0000080       ; IA32_EFER MSR
    rdmsr
    or eax, 1 << 8            ; LME Bit
    wrmsr

    ; CR0.PG = 1
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ; JUMP INTO 64-BIT MODE
    jmp 0x08:stage2_64         ; Code Segment = 0x08


; ===============================
; 64-Bit Code beginnt hier
; ===============================
bits 64

section .text

stage2_64:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

    mov rdi, msg64
    call print_string64

hang:
    hlt
    jmp hang


; ---------------------------------
; 64-bit String Printer
; ---------------------------------
print_string64:
    ; RDI = pointer
.next:
    mov al, byte [rdi]
    cmp al, 0
    je .done

    mov ah, 0x0E
    int 0x10

    inc rdi
    jmp .next
.done:
    ret

section .data
msg64 db "Hello from 64-bit mode!", 0


; Boot area for stage2: pad (no need for boot signature here)
