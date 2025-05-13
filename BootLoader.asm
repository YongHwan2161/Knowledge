[BITS 16]           ; 16-bit real mode
[ORG 0x7C00]        ; BIOS loads bootloader at this address

; Set up segment registers
mov ax, 0x0000
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7c00      ; Set up stack pointer

; Print welcome message
mov si, boot_msg
call print_string

; Set standard VGA mode for bootloader operation
mov ah, 0x00        ; Set video mode function
mov al, 0x12        ; Mode 12h (640x480, 16 colors)
int 0x10

; Load second stage bootloader
mov ah, 0x02        ; BIOS read sector function
mov al, 12          ; Load 12 sectors (6KB should be enough for the larger screen)
mov ch, 0           ; Cylinder 0
mov cl, 2           ; Sector 2 (1-based, sector after boot sector)
mov dh, 0           ; Head 0
mov dl, 0x80        ; First hard drive
mov bx, 0x1000      ; Buffer address
int 0x13
jc read_error       ; Jump if carry flag set (error)

; Basic VESA detection (just to inform second stage if VESA is available)
mov ax, 0x4F00      ; VBE function 00h - Return VBE Controller Information
mov di, 0x8000      ; ES:DI points to a 512-byte buffer
int 0x10
cmp ax, 0x004F      ; AL=4Fh if function supported, AH=00h if successful
je vesa_detected

; If VESA isn't detected, set a flag for the second stage
mov byte [0x8000], 0  ; VESA not available
jmp continue_boot

vesa_detected:
mov byte [0x8000], 1  ; VESA available

continue_boot:
; Enable A20 line
call enable_a20

; Load GDT
lgdt [gdt_descriptor]

; Switch to protected mode
cli                 ; Disable interrupts
mov eax, cr0        ; Set PE bit in CR0
or eax, 1
mov cr0, eax

; Jump to 32-bit code (second stage bootloader)
jmp 0x08:0x1000     ; Jump to the loaded second stage at second_stage_start

; Error handler
read_error:
    mov si, error_msg
    call print_string
    jmp $            ; Infinite loop

; Function to print a string in real mode
print_string:
    mov ah, 0x0E    ; BIOS teletype function
.loop:
    lodsb           ; Load byte from SI into AL and increment SI
    test al, al     ; Check if character is null (end of string)
    jz .done        ; If zero, we're done
    int 0x10        ; Print character
    jmp .loop       ; Repeat for next character
.done:
    ret

; Function to enable A20 line
enable_a20:
    in al, 0x92    ; Read port 0x92
    or al, 2       ; Set bit 1
    out 0x92, al   ; Write back
    ret

; Global Descriptor Table (GDT)
gdt_start:
    ; Null descriptor
    dd 0x0
    dd 0x0

    ; Code segment descriptor
    dw 0xFFFF       ; Limit (bits 0-15)
    dw 0x0000       ; Base (bits 0-15)
    db 0x00         ; Base (bits 16-23)
    db 10011010b    ; Access byte
    db 11001111b    ; Flags and Limit (bits 16-19)
    db 0x00         ; Base (bits 24-31)

    ; Data segment descriptor
    dw 0xFFFF       ; Limit (bits 0-15)
    dw 0x0000       ; Base (bits 0-15)
    db 0x00         ; Base (bits 16-23)
    db 10010010b    ; Access byte
    db 11001111b    ; Flags and Limit (bits 16-19)
    db 0x00         ; Base (bits 24-31)

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; Size of GDT
    dd gdt_start                ; Address of GDT

; Messages
boot_msg db 'Loading second stage bootloader...', 13, 10, 0
error_msg db 'Error loading second stage!', 13, 10, 0

; Boot signature
times 510-($-$$) db 0
db 0x55, 0xAA       ; BIOS signature
