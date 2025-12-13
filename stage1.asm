; stage1.asm - Bootsector (512 bytes)
; Lädt Stage2 ab LBA 1 nach 0x0000:0x8000
bits 16
org 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl   ; BIOS Bootdrive speichern

    mov si, msg1
    call print_string

    mov ax, 0x0000
    mov es, ax
    mov bx, 0x8000         ; Zieloffset für Stage2

    mov word [lba_counter], 1
    mov word [sectors_left], SECTORS_TO_LOAD

load_next:
    ; ===============================
    ; Berechne CHS
    ; ===============================
    mov ax, [lba_counter]  ; aktueller LBA
    xor dx, dx
    mov cx, 36             ; Sektoren pro Zylinder (2 Heads * 18 Sektoren/Track)
    div cx                 ; AX = Cylinder, DX = Offset innerhalb Cylinder
    mov di, ax             ; DI = Cylinder

    mov ax, dx
    xor dx, dx
    mov cx, 18             ; Sektoren pro Track
    div cx                 ; AX = Head, DX = Sector innerhalb Track

    mov ch, al             ; CH = Cylinder low byte
    mov dh, ah             ; DH = Head
    mov cl, dl
    inc cl                 ; Sektornummer 1-basiert

    ; ===============================
    ; BIOS Interrupt 0x13: Sektor lesen
    ; ===============================
    mov ah, 0x02           ; Funktion 2: read sector
    mov al, 0x01           ; 1 Sektor lesen
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; ES:BX erhöhen
    add bx, 512
    jnc .no_carry
    inc word [dest_seg]
    mov ax, [dest_seg]
    mov es, ax
.no_carry:

    ; Zähler aktualisieren
    dec word [sectors_left]
    cmp word [sectors_left], 0
    jne .continue
    jmp jump_to_stage2

.continue:
    inc word [lba_counter]
    jmp load_next

disk_error:
    mov si, err1
    call print_string
    cli
    hlt

jump_to_stage2:
    jmp 0x0000:0x8000

; ------------------------------
; Hilfsroutine: BIOS-Textausgabe
; ------------------------------
print_string:
    mov ah, 0x0E
.nextp:
    lodsb
    cmp al, 0
    je .donep
    int 0x10
    jmp .nextp
.donep:
    ret

msg1 db "Stage1: loading stage2...",0
err1 db "Disk read error!",0

; Variablen
boot_drive db 0
dest_seg dw 0x0000
lba_counter dw 0
sectors_left dw 0

SECTORS_TO_LOAD equ 8   ; <--- auf Stage2 Sektoren anpassen

; Bootsektor Padding
times 510 - ($ - $$) db 0
dw 0xAA55
