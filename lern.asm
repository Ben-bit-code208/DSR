; ==============================
; 16-Bit Bootloader + Konsole
; ==============================
bits 16
org 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Cursor init
    mov word [cursor_x], 0
    mov word [cursor_y], 0

    ; Nachricht ausgeben
    mov si, msg
    call print_string

    ; 32-Bit Protected Mode starten
    jmp protected_mode_entry

hang: jmp hang

print_string:
    mov ah, 0x0E
.next:
    lodsb
    cmp al,0
    je .done
    int 0x10
    jmp .next
.done:
    ret

msg db "Bootloader loaded. Switching to 32-bit...",0

cursor_x dw 0
cursor_y dw 0

; ==============================
; 32-Bit Protected Mode Setup
; ==============================
bits 32

protected_mode_entry:
    ; GDT Setup
    gdt_start:
        dq 0x0000000000000000        ; Null
        dq 0x00CF9A000000FFFF        ; Code
        dq 0x00CF92000000FFFF        ; Data
    gdt_end:

    gdt_descriptor:
        dw gdt_end - gdt_start -1
        dd gdt_start

    lgdt [gdt_descriptor]

    ; Protected Mode aktivieren
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far Jump zu init_pm
    jmp 0x08:init_pm

init_pm:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000      ; Stack für 32-Bit

    ; Minimal: 64-Bit Entry
    jmp 0x08:long_mode_entry

; ==============================
; 64-Bit Long Mode Entry
; ==============================
bits 64

long_mode_entry:
    ; Hier bist du offiziell 64-Bit
    ; Ab hier kannst du EFI oder Kernel laden
    hlt

; ==============================
; Bootsector Padding
; ==============================
times 510 - ($-$$) db 0
dw 0xAA55
