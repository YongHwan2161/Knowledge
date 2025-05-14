[BITS 32]
[ORG 0x1000]       ; Second stage loaded at this address

start:
    ; Set up segment registers for protected mode
    mov ax, 0x10    ; Data segment selector
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Initialize disk controller
    call disk_init

    ; Check if VESA is available (set by bootloader)
    cmp byte [0x8000], 1
    je setup_vesa_mode

    ; If VESA not available, keep the VGA mode already set
    jmp vga_mode_ready

setup_vesa_mode:
    ; We need to switch back to real mode to set VESA mode
    ; This is quite complex, so we'll stay with VGA mode 0x12 for now
        ; mov esi, vesa_msg
    ; mov edi, 0
    ; mov ebx, 0
    ; mov ah, 14
    ; call print_string
    ; To be implemented in a future version
    ; jmp setup_real_mode_trampoline

vga_mode_ready:
    ; Initialize basic 16-color palette for compatibility 
    ; (not strictly needed for VGA but good for consistency)
    call init_palette

    ; Clear the screen (black background)
    call clear_screen

    ; Draw a border around the screen
    ; mov ecx, 0      ; X start
    ; mov edx, 0      ; Y start
    ; mov esi, 639    ; X end
    ; mov edi, 479    ; Y end
    ; mov ah, 14      ; Yellow color
    ; call draw_rectangle_border

    ; Print welcome message
    mov esi, welcome_msg
    mov edi, 380    ; X position
    mov ebx, 0      ; Y position
    mov ah, 13      ; Yellow color (decimal 14, not binary)
    call print_string

    ; Print a number
    mov eax, 12345  ; Number to print
    mov edi, 380    ; X position
    mov ebx, 10     ; Y position
    mov cl, 14      ; Yellow color (decimal 14, not binary)
    call print_decimal

    ; Set up buffer to read disk data
    mov edi, disk_buffer
    mov eax, 0      ; LBA address
    mov ecx, 1      ; Read 1 sector
    call disk_read_sectors

    ; Display disk buffer contents
    mov esi, disk_buffer
    mov edi, 0      ; X position
    mov ebx, 0      ; Y position
    call display_disk_buffer
    
    ; Initialize and display cursor at the first hex digit
    mov al, 0       ; X position (first hex digit)
    mov ah, 0       ; Y position (first row)
    mov bl, 15       ; Light blue color (change as desired)
    call draw_cursor

    ; Display keyboard input message
    mov esi, keyboard_msg
    mov edi, 0      ; X position
    mov ebx, 470    ; Y position at bottom of screen
    mov ah, 15      ; White color (decimal 15)
    call print_string

    ; Initialize input buffer position
    mov edi, 160    ; X position for input (after message)
    mov ebx, 470    ; Y position
    mov byte [input_position], 0

main_loop:
    ; Check for keyboard input
    call check_keyboard
    
    ; Endless loop
    jmp main_loop

; Function to initialize a basic 16-color palette (for compatibility)
init_palette:
    pusha
    
    ; For standard VGA mode 0x12, the palette is already set
    ; This function is a placeholder for future VESA implementation
    
    popa
    ret

; Function to print a byte as hex
print_hex_byte:
    pusha
    
    ; High nibble
    mov al, [esi]
    shr al, 4
    call hex_convert_nibble
    mov [hex_chars], al
    
    ; Low nibble
    mov al, [esi]
    and al, 0x0F
    call hex_convert_nibble
    mov [hex_chars+1], al
    
    ; Display the hex value
    mov esi, hex_chars
    call print_string
    
    popa
    ret
    
hex_convert_nibble:
    cmp al, 10
    jb .is_digit
    add al, 'A' - 10 - '0'  ; Convert to A-F
.is_digit:
    add al, '0'             ; Convert to ASCII
    ret
    
hex_chars: db "00", 0

; Function to print a 16-bit word as hex (4 digits)
print_hex_word:
    pusha
    
    ; Print high byte first (bits 8-15)
    mov bx, ax      ; Save the full value in BX
    mov al, ah      ; High byte to AL
    mov ah, 14      ; Yellow color
    call print_hex_byte
    
    ; Print low byte (bits 0-7)
    mov al, bl      ; Low byte to AL 
    add edi, 24     ; Move to next position
    mov ah, 14      ; Yellow color
    call print_hex_byte
    
    popa
    ret

; -------------------- Disk I/O Functions --------------------

; Function to read sectors from disk in protected mode
; Input: EAX = LBA address, ECX = number of sectors to read, EDI = buffer address
disk_read_sectors:
    pusha
    
    ; Make sure EBX contains the LBA from EAX
    mov ebx, eax
    
    ; Configure base I/O ports - using primary ATA controller
    mov dx, 0x1F6   ; Drive/Head port
    mov al, 11100000b    ; LBA mode, use primary drive
    out dx, al
    
    ; Send sectors count
    mov dx, 0x1F2   ; Sector count port
    mov al, cl      ; Number of sectors
    out dx, al
    
    ; Send LBA address (24 bits: LBA 0-23)
    mov dx, 0x1F3   ; LBA low port (0-7)
    mov al, bl      ; LBA 0-7 bits
    out dx, al
    
    mov dx, 0x1F4   ; LBA mid port (8-15)
    mov al, bh      ; LBA 8-15 bits
    out dx, al
    
    mov dx, 0x1F5   ; LBA high port (16-23)
    shr ebx, 16     ; Get high word
    mov al, bl      ; LBA 16-23 bits
    out dx, al
    
    ; Send read command
    mov dx, 0x1F7   ; Command port
    mov al, 0x20    ; READ SECTORS command
    out dx, al
    
    ; Remember sector count
    mov bl, cl
    
.read_next:
    ; Wait for data to be ready
    mov dx, 0x1F7   ; Status port
.wait_ready:
    in al, dx
    test al, 8      ; Test if data ready (bit 3)
    jz .wait_ready
    
    ; Read data (256 words = 1 sector)
    mov cx, 256     ; 256 words = 512 bytes
    mov dx, 0x1F0   ; Data port
.read_data:
    in ax, dx       ; Read word from disk
    mov [edi], ax   ; Store to memory
    add edi, 2      ; Move to next word
    loop .read_data
    
    ; Check if we need to read more sectors
    dec bl          ; Decrement sector count
    jz .read_done   ; If zero, we're done
    
    ; Small delay to allow controller to prepare next sector
    mov ecx, 10
.read_delay:
    in al, 0x80     ; Dummy read for delay
    loop .read_delay
    
    jmp .read_next
    
.read_done:
    popa
    ret

; Function to initialize disk system
disk_init:
    pusha
    
    ; Reset disk controller
    mov dx, 0x1F7   ; Command port
    mov al, 0x04    ; RESET command
    out dx, al
    
    ; Small delay
    mov ecx, 100
.disk_delay:
    in al, 0x80     ; Dummy read for delay
    loop .disk_delay
    
    ; Check status
    mov dx, 0x1F7   ; Status port
    in al, dx
    test al, 0x80   ; Test BSY bit
    jnz disk_init   ; If busy, retry
    
    popa
    ret

; Function to clear screen
clear_screen:
    pusha
    
    ; Get the framebuffer address 
    mov edi, 0xA0000        ; Linear framebuffer base address
    
    ; For VGA mode 0x12 (planar mode)
    ; Set all planes to be written to
    mov dx, 0x3C4   ; Sequencer Address Register
    mov al, 0x02    ; Map Mask Register
    out dx, al
    inc dx          ; Sequencer Data Register (0x3C5)
    mov al, 0x0F    ; Set all 4 planes
    out dx, al
    
    ; Clear the screen
    xor eax, eax            ; Set to zero (black)
    mov ecx, 38400          ; 640*480/8 = 38400 bytes (each byte controls 8 pixels)
    rep stosd               ; Clear screen faster with dword operations
    
    popa
    ret

; set_pixel: Plot a pixel in VGA Mode 12h (640×480, 16-color planar)
; Inputs:
;   ECX = X coordinate (0..639)
;   EDX = Y coordinate (0..479)
;   AL  = color index (0..15)
set_pixel:
    pushad                           ; Preserve all registers

    ; Save the color value from AL to a safe place (stack)
    movzx ebx, al                    ; EBX = color (0-15)
    and ebx, 0x0F                    ; Ensure only lower 4 bits are used
    push ebx                         ; Save color on stack

    ; Compute byte offset: offset = Y*80 + (X/8)
    mov eax, edx                     ; EAX = Y
    mov ebx, 80                      ; bytes per row in Mode 12h 
    mul ebx                          ; EAX = Y * 80
    mov ebx, ecx                     ; EBX = X
    shr ebx, 3                       ; EBX = X / 8
    add eax, ebx                     ; EAX = Y*80 + X/8
    add eax, 0xA0000                 ; EAX = linear video address (0xA0000+offset)
    mov edi, eax                     ; EDI = final memory address

    ; Compute bit mask (1 << (7 - (X % 8)))
    mov eax, ecx                     ; EAX = X
    and eax, 7                       ; EAX = X % 8
    mov cl, 7                        ; CL = 7
    sub cl, al                       ; CL = 7 - (X % 8)
    mov bl, 1                        ; BL = 1
    shl bl, cl                       ; BL = 1 << (7 - (X % 8))

    ; Set up the Bit Mask Register
    mov dx, 0x3CE                    ; Graphics Controller Index
    mov al, 0x08                     ; Select Bit Mask Register (index 8)
    out dx, al
    inc dx                           ; Graphics Controller Data (0x3CF)
    mov al, bl                       ; AL = bit mask
    out dx, al
    
    ; Configure for write mode 0
    mov dx, 0x3CE                    ; Graphics Controller Index
    mov al, 0x05                     ; Select Mode Register (index 5)
    out dx, al
    inc dx                           ; Graphics Controller Data (0x3CF)
    mov al, 0x00                     ; Mode 0 (write mode 0)
    out dx, al

    ; Set the color register using our saved color
    mov dx, 0x3CE                    ; Graphics Controller Index
    mov al, 0x00                     ; Select Set/Reset Register (index 0)
    out dx, al
    inc dx                           ; Graphics Controller Data (0x3CF)
    pop ebx                          ; Get saved color value
    mov al, bl                       ; AL = color
    out dx, al                       ; Set color

    ; Enable Set/Reset for all planes
    mov dx, 0x3CE                    ; Graphics Controller Index
    mov al, 0x01                     ; Select Enable Set/Reset Register (index 1)
    out dx, al
    inc dx                           ; Graphics Controller Data (0x3CF)
    mov al, 0x0F                     ; Enable for all planes
    out dx, al

    ; Write to video memory to set the pixel
    mov al, [edi]                    ; Latch data (dummy read)
    mov [edi], al                    ; Write to video memory

    popad                            ; Restore registers
    ret

; Function to draw a line
; Input: ECX = X1, EDX = Y1, ESI = X2, EDI = Y2, AL = color
draw_line:
    pusha
    ; [Implementation omitted for brevity - to be implemented]
    popa
    ret

; Function to draw a rectangle border
; Input: ECX = X1, EDX = Y1, ESI = X2, EDI = Y2, AH = color
draw_rectangle_border:
    pusha
    
    ; Draw top line
    mov eax, 0
    mov al, ah       ; Set color
    push ecx
    push edx
    push esi
    push edi
    ; X remains ECX, Y remains EDX, ESI becomes X2, EDI becomes Y1
    mov edi, edx     ; Y1 to Y1 (no change)
    call draw_horizontal_line
    pop edi
    pop esi
    pop edx
    pop ecx
    
    ; Draw bottom line
    
    push ecx
    push edx
    push esi
    push edi
    mov edx, edi     ; Y1 becomes Y2
    call draw_horizontal_line
    pop edi
    pop esi
    pop edx
    pop ecx
    
    ; Draw left line
    push ecx
    push edx
    push esi
    push edi
    ; X1 remains ECX, Y1 remains EDX, ESI becomes X1, EDI stays Y2
    mov esi, ecx    ; X2 becomes X1
    call draw_vertical_line
    pop edi
    pop esi
    pop edx
    pop ecx
    
    ; Draw right line
    push ecx
    push edx
    push esi
    push edi
    mov ecx, esi    ; X1 becomes X2
    call draw_vertical_line
    pop edi
    pop esi
    pop edx
    pop ecx
    
    popa
    ret

; Draw horizontal line
; Input: ECX = X1, EDX = Y, ESI = X2, AL = color
draw_horizontal_line:
    pushad                      ; Save all registers
    
    ; Make sure X1 <= X2
    cmp ecx, esi
    jle .x_ordered
    xchg ecx, esi
.x_ordered:
    
    ; Save color in BL
    mov bl, al
    
    ; Draw the line
.draw_h_loop:
    mov al, bl                 ; Restore color to AL for set_pixel
    call set_pixel
    inc ecx
    cmp ecx, esi
    jle .draw_h_loop
    
    popad                      ; Restore all registers
    ret

; Draw vertical line
; Input: ECX = X, EDX = Y1, EDI = Y2, AL = color
draw_vertical_line:
    pusha
    
    ; Make sure Y1 <= Y2
    cmp edx, edi
    jle .y_ordered
    xchg edx, edi
.y_ordered:
    
    ; Draw the line
.draw_v_loop:
    push eax
    call set_pixel
    pop eax
    inc edx
    cmp edx, edi
    jle .draw_v_loop
    
    popa
    ret

; Function to print a character using bitmap font
; Input: AL = character, AH = color (0-15), EDI = X position, EBX = Y position
; IMPORTANT: Color must be in AH, not AL
print_char:
    pusha
    
    ; Handle different character ranges
    cmp al, ' '     ; Check if it's a space or control character
    jl .done        ; Skip control characters
    
    ; Get the font data for the character
    movzx esi, al
    sub esi, ' '    ; Adjust for font table starting at ASCII 32 (space)
    imul esi, 8     ; Multiply by 8 bytes per character
    add esi, font_data
    
    ; Draw the character (8x8 pixels)
    mov ecx, 8      ; 8 rows
.char_loop_y:
    mov dl, [esi]   ; Get row bitmap data
    test dl, dl     ; Check if the data is valid
    jz .next_row    ; Skip empty rows
    
    push edi
    mov ebp, 8      ; 8 columns
.char_loop_x:
    bt edx, 7       ; Test the leftmost bit
    jnc .skip_pixel ; If bit is 0, skip drawing
    
    ; Draw the pixel
    push eax
    push ecx
    push edx
    
    ; Keep original color from AH
    mov al, ah      ; Set color value
    mov ecx, edi    ; X position
    mov edx, ebx    ; Y position
    call set_pixel
    
    pop edx
    pop ecx
    pop eax
    
.skip_pixel:
    inc edi         ; Move right one pixel
    shl edx, 1      ; Shift to next bit
    dec ebp         ; Decrement column counter
    jnz .char_loop_x
    
    pop edi
.next_row:
    inc ebx         ; Move down one row
    inc esi         ; Next byte of font data
    loop .char_loop_y
    
.done:
    popa
    ret

; Function to print a string
; Input: ESI = string address, EDI = X position, EBX = Y position, AH = color (0-15)
; IMPORTANT: Color must be in AH, not AL
print_string:
    pusha
.loop:
    lodsb           ; Load next character to AL (preserves AH which has color)
    test al, al     ; Check if character is null (end of string)
    jz .done        ; If zero, we're done
    
    call print_char ; Print the character
    add edi, 8      ; Move X position for next character
    
    ; Check if we need to wrap to next line
    cmp edi, 640-8
    jl .loop        ; If we're still within screen bounds, continue
    
    ; Wrap to next line
    mov edi, 20     ; Reset X to starting position
    add ebx, 9      ; Move to next line (8 pixels + 1 for spacing)
    jmp .loop
    
.done:
    popa
    ret

; Function to print a decimal number
; Input: EAX = number to print, EDI = X position, EBX = Y position, CL = color (0-15)
; IMPORTANT: Color must be in CL, not AL or AH
print_decimal:
    pusha
    mov ch, cl      ; Save color in CH
    
    ; Check if number is zero
    test eax, eax
    jnz .not_zero
    
    ; Print '0' if number is zero
    mov al, '0'
    mov ah, ch      ; Set color
    call print_char
    popa
    ret
    
.not_zero:
    ; Count digits and push them onto the stack
    mov ecx, 0      ; Digit counter
    mov edx, 0
    mov esi, 10     ; Divisor
    
.push_digits:
    div esi         ; Divide EDX:EAX by 10, quotient in EAX, remainder in EDX
    add dl, '0'     ; Convert remainder to ASCII
    push edx        ; Save digit on stack
    inc ecx         ; Increment digit counter
    xor edx, edx    ; Clear EDX for next division
    test eax, eax   ; Check if quotient is zero
    jnz .push_digits ; If not, continue
    
    ; Pop digits and print them
    mov ah, ch      ; Set color
.print_digits:
    pop eax         ; Get digit from stack
    call print_char ; Print the digit
    add edi, 8      ; Move X position for next character
    loop .print_digits
    
    popa
    ret

; Complete font data (8x8 font for ASCII 32-127)
font_data:
; ASCII 32 - Space
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 00000000b

; ASCII 33 - !
db 00011000b
db 00011000b
db 00011000b
db 00011000b
db 00011000b
db 00000000b
db 00011000b
db 00000000b

; ASCII 34 - "
db 01100110b
db 01100110b
db 01100110b
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 00000000b

; ASCII 35 - #
db 00100100b
db 00100100b
db 01111110b
db 00100100b
db 01111110b
db 00100100b
db 00100100b
db 00000000b

; ASCII 36 - $
db 00011000b
db 00111110b
db 01100000b
db 00111100b
db 00000110b
db 01111100b
db 00011000b
db 00000000b

; ASCII 37 - %
db 01100110b
db 01100110b
db 00001100b
db 00011000b
db 00110000b
db 01100110b
db 01100110b
db 00000000b

; ASCII 38 - &
db 00111000b
db 01101100b
db 01111000b
db 01110110b
db 01101100b
db 01100110b
db 00111011b
db 00000000b

; ASCII 39 - '
db 00011000b
db 00011000b
db 00110000b
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 00000000b

; ASCII 40 - (
db 00001100b
db 00011000b
db 00110000b
db 00110000b
db 00110000b
db 00011000b
db 00001100b
db 00000000b

; ASCII 41 - )
db 00110000b
db 00011000b
db 00001100b
db 00001100b
db 00001100b
db 00011000b
db 00110000b
db 00000000b

; ASCII 42 - *
db 00000000b
db 00011000b
db 01111110b
db 00111100b
db 01111110b
db 00011000b
db 00000000b
db 00000000b

; ASCII 43 - +
db 00000000b
db 00011000b
db 00011000b
db 01111110b
db 00011000b
db 00011000b
db 00000000b
db 00000000b

; ASCII 44 - ,
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 00011000b
db 00011000b
db 00110000b

; ASCII 45 - -
db 00000000b
db 00000000b
db 00000000b
db 01111110b
db 00000000b
db 00000000b
db 00000000b
db 00000000b

; ASCII 46 - .
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 00011000b
db 00011000b
db 00000000b

; ASCII 47 - /
db 00000000b
db 00000110b
db 00001100b
db 00011000b
db 00110000b
db 01100000b
db 01000000b
db 00000000b

; ASCII 48 - 0
db 00111100b
db 01100110b
db 01101110b
db 01110110b
db 01100110b
db 01100110b
db 00111100b
db 00000000b

; ASCII 49 - 1
db 00011000b
db 00111000b
db 00011000b
db 00011000b
db 00011000b
db 00011000b
db 01111110b
db 00000000b

; ASCII 50 - 2
db 00111100b
db 01100110b
db 00000110b
db 00001100b
db 00110000b
db 01100000b
db 01111110b
db 00000000b

; ASCII 51 - 3
db 00111100b
db 01100110b
db 00000110b
db 00011100b
db 00000110b
db 01100110b
db 00111100b
db 00000000b

; ASCII 52 - 4
db 00001100b
db 00011100b
db 00111100b
db 01101100b
db 01111110b
db 00001100b
db 00001100b
db 00000000b

; ASCII 53 - 5
db 01111110b
db 01100000b
db 01100000b
db 01111100b
db 00000110b
db 01100110b
db 00111100b
db 00000000b

; ASCII 54 - 6
db 00111100b
db 01100110b
db 01100000b
db 01111100b
db 01100110b
db 01100110b
db 00111100b
db 00000000b

; ASCII 55 - 7
db 01111110b
db 01100110b
db 00001100b
db 00011000b
db 00110000b
db 00110000b
db 00110000b
db 00000000b

; ASCII 56 - 8
db 00111100b
db 01100110b
db 01100110b
db 00111100b
db 01100110b
db 01100110b
db 00111100b
db 00000000b

; ASCII 57 - 9
db 00111100b
db 01100110b
db 01100110b
db 00111110b
db 00000110b
db 01100110b
db 00111100b
db 00000000b

; ASCII 58 - :
db 00000000b
db 00011000b
db 00011000b
db 00000000b
db 00000000b
db 00011000b
db 00011000b
db 00000000b

; ASCII 59 - ;
db 00000000b
db 00011000b
db 00011000b
db 00000000b
db 00000000b
db 00011000b
db 00011000b
db 00110000b

; ASCII 60 - <
db 00001110b
db 00011000b
db 00110000b
db 01100000b
db 00110000b
db 00011000b
db 00001110b
db 00000000b

; ASCII 61 - =
db 00000000b
db 00000000b
db 01111110b
db 00000000b
db 01111110b
db 00000000b
db 00000000b
db 00000000b

; ASCII 62 - >
db 01110000b
db 00011000b
db 00001100b
db 00000110b
db 00001100b
db 00011000b
db 01110000b
db 00000000b

; ASCII 63 - ?
db 00111100b
db 01100110b
db 00000110b
db 00001100b
db 00011000b
db 00000000b
db 00011000b
db 00000000b

; ASCII 64 - @
db 00111100b
db 01100110b
db 01101110b
db 01101110b
db 01110000b
db 01100000b
db 00111100b
db 00000000b

; ASCII 65 - A
db 00111100b
db 01100110b
db 01100110b
db 01111110b
db 01100110b
db 01100110b
db 01100110b
db 00000000b

; ASCII 66 - B
db 01111100b
db 01100110b
db 01100110b
db 01111100b
db 01100110b
db 01100110b
db 01111100b
db 00000000b

; ASCII 67 - C
db 00111100b
db 01100110b
db 01100000b
db 01100000b
db 01100000b
db 01100110b
db 00111100b
db 00000000b

; ASCII 68 - D
db 01111000b
db 01101100b
db 01100110b
db 01100110b
db 01100110b
db 01101100b
db 01111000b
db 00000000b

; ASCII 69 - E
db 01111110b
db 01100000b
db 01100000b
db 01111100b
db 01100000b
db 01100000b
db 01111110b
db 00000000b

; ASCII 70 - F
db 01111110b
db 01100000b
db 01100000b
db 01111100b
db 01100000b
db 01100000b
db 01100000b
db 00000000b

; ASCII 71 - G
db 00111100b
db 01100110b
db 01100000b
db 01101110b
db 01100110b
db 01100110b
db 00111110b
db 00000000b

; ASCII 72 - H
db 01100110b
db 01100110b
db 01100110b
db 01111110b
db 01100110b
db 01100110b
db 01100110b
db 00000000b

; ASCII 73 - I
db 00111100b
db 00011000b
db 00011000b
db 00011000b
db 00011000b
db 00011000b
db 00111100b
db 00000000b

; ASCII 74 - J
db 00011110b
db 00001100b
db 00001100b
db 00001100b
db 01101100b
db 01101100b
db 00111000b
db 00000000b

; ASCII 75 - K
db 01100110b
db 01101100b
db 01111000b
db 01110000b
db 01111000b
db 01101100b
db 01100110b
db 00000000b

; ASCII 76 - L
db 01100000b
db 01100000b
db 01100000b
db 01100000b
db 01100000b
db 01100000b
db 01111110b
db 00000000b

; ASCII 77 - M
db 01100011b
db 01110111b
db 01111111b
db 01101011b
db 01100011b
db 01100011b
db 01100011b
db 00000000b

; ASCII 78 - N
db 01100110b
db 01110110b
db 01111110b
db 01111110b
db 01101110b
db 01100110b
db 01100110b
db 00000000b

; ASCII 79 - O
db 00111100b
db 01100110b
db 01100110b
db 01100110b
db 01100110b
db 01100110b
db 00111100b
db 00000000b

; ASCII 80 - P
db 01111100b
db 01100110b
db 01100110b
db 01111100b
db 01100000b
db 01100000b
db 01100000b
db 00000000b

; ASCII 81 - Q
db 00111100b
db 01100110b
db 01100110b
db 01100110b
db 01101110b
db 01111100b
db 00001110b
db 00000000b

; ASCII 82 - R
db 01111100b
db 01100110b
db 01100110b
db 01111100b
db 01111000b
db 01101100b
db 01100110b
db 00000000b

; ASCII 83 - S
db 00111100b
db 01100110b
db 01100000b
db 00111100b
db 00000110b
db 01100110b
db 00111100b
db 00000000b

; ASCII 84 - T
db 01111110b
db 00011000b
db 00011000b
db 00011000b
db 00011000b
db 00011000b
db 00011000b
db 00000000b

; ASCII 85 - U
db 01100110b
db 01100110b
db 01100110b
db 01100110b
db 01100110b
db 01100110b
db 00111100b
db 00000000b

; ASCII 86 - V
db 01100110b
db 01100110b
db 01100110b
db 01100110b
db 01100110b
db 00111100b
db 00011000b
db 00000000b

; ASCII 87 - W
db 00000000b
db 00000000b
db 01100011b
db 01101011b
db 01111111b
db 01111111b
db 00110110b
db 00000000b

; ASCII 88 - X
db 01100110b
db 01100110b
db 00111100b
db 00011000b
db 00111100b
db 01100110b
db 01100110b
db 00000000b

; ASCII 89 - Y
db 01100110b
db 01100110b
db 01100110b
db 00111100b
db 00011000b
db 00011000b
db 00011000b
db 00000000b

; ASCII 90 - Z
db 01111110b
db 00000110b
db 00001100b
db 00011000b
db 00110000b
db 01100000b
db 01111110b
db 00000000b

; ASCII 91 - [
db 00111100b
db 00110000b
db 00110000b
db 00110000b
db 00110000b
db 00110000b
db 00111100b
db 00000000b

; ASCII 92 - \
db 01000000b
db 01100000b
db 00110000b
db 00011000b
db 00001100b
db 00000110b
db 00000010b
db 00000000b

; ASCII 93 - ]
db 00111100b
db 00001100b
db 00001100b
db 00001100b
db 00001100b
db 00001100b
db 00111100b
db 00000000b

; ASCII 94 - ^
db 00011000b
db 00111100b
db 01100110b
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 00000000b

; ASCII 95 - _
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 01111110b
db 00000000b

; ASCII 96 - `
db 00110000b
db 00011000b
db 00001100b
db 00000000b
db 00000000b
db 00000000b
db 00000000b
db 00000000b

; ASCII 97 - a
db 00000000b
db 00000000b
db 00111100b
db 00000110b
db 00111110b
db 01100110b
db 00111110b
db 00000000b

; ASCII 98 - b
db 01100000b
db 01100000b
db 01111100b
db 01100110b
db 01100110b
db 01100110b
db 01111100b
db 00000000b

; ASCII 99 - c
db 00000000b
db 00000000b
db 00111100b
db 01100110b
db 01100000b
db 01100110b
db 00111100b
db 00000000b

; ASCII 100 - d
db 00000110b
db 00000110b
db 00111110b
db 01100110b
db 01100110b
db 01100110b
db 00111110b
db 00000000b

; ASCII 101 - e
db 00000000b
db 00000000b
db 00111100b
db 01100110b
db 01111110b
db 01100000b
db 00111100b
db 00000000b

; ASCII 102 - f
db 00011100b
db 00110110b
db 00110000b
db 01111100b
db 00110000b
db 00110000b
db 00110000b
db 00000000b

; ASCII 103 - g
db 00000000b
db 00000000b
db 00111110b
db 01100110b
db 01100110b
db 00111110b
db 00000110b
db 01111100b

; ASCII 104 - h
db 01100000b
db 01100000b
db 01111100b
db 01100110b
db 01100110b
db 01100110b
db 01100110b
db 00000000b

; ASCII 105 - i
db 00011000b
db 00000000b
db 00111000b
db 00011000b
db 00011000b
db 00011000b
db 00111100b
db 00000000b

; ASCII 106 - j
db 00001100b
db 00000000b
db 00011100b
db 00001100b
db 00001100b
db 00001100b
db 01101100b
db 00111000b

; ASCII 107 - k
db 01100000b
db 01100000b
db 01100110b
db 01101100b
db 01111000b
db 01101100b
db 01100110b
db 00000000b

; ASCII 108 - l
db 00111000b
db 00011000b
db 00011000b
db 00011000b
db 00011000b
db 00011000b
db 00111100b
db 00000000b

; ASCII 109 - m
db 00000000b
db 00000000b
db 01100110b
db 01111111b
db 01111111b
db 01101011b
db 01100011b
db 00000000b

; ASCII 110 - n
db 00000000b
db 00000000b
db 01111100b
db 01100110b
db 01100110b
db 01100110b
db 01100110b
db 00000000b

; ASCII 111 - o
db 00000000b
db 00000000b
db 00111100b
db 01100110b
db 01100110b
db 01100110b
db 00111100b
db 00000000b

; ASCII 112 - p
db 00000000b
db 00000000b
db 01111100b
db 01100110b
db 01100110b
db 01111100b
db 01100000b
db 01100000b

; ASCII 113 - q
db 00000000b
db 00000000b
db 00111110b
db 01100110b
db 01100110b
db 00111110b
db 00000110b
db 00000111b

; ASCII 114 - r
db 00000000b
db 00000000b
db 01111100b
db 01100110b
db 01100000b
db 01100000b
db 01100000b
db 00000000b

; ASCII 115 - s
db 00000000b
db 00000000b
db 00111100b
db 01100000b
db 00111100b
db 00000110b
db 01111100b
db 00000000b

; ASCII 116 - t
db 00011000b
db 00011000b
db 01111110b
db 00011000b
db 00011000b
db 00011010b
db 00001100b
db 00000000b

; ASCII 117 - u
db 00000000b
db 00000000b
db 01100110b
db 01100110b
db 01100110b
db 01100110b
db 00111110b
db 00000000b

; ASCII 118 - v
db 00000000b
db 00000000b
db 01100110b
db 01100110b
db 01100110b
db 00111100b
db 00011000b
db 00000000b

; ASCII 119 - w
db 00000000b
db 00000000b
db 01100011b
db 01101011b
db 01111111b
db 01111111b
db 00110110b
db 00000000b

; ASCII 120 - x
db 00000000b
db 00000000b
db 01100110b
db 00111100b
db 00011000b
db 00111100b
db 01100110b
db 00000000b

; ASCII 121 - y
db 00000000b
db 00000000b
db 01100110b
db 01100110b
db 01100110b
db 00111110b
db 00001100b
db 01111000b

; ASCII 122 - z
db 00000000b
db 00000000b
db 01111110b
db 00001100b
db 00011000b
db 00110000b
db 01111110b
db 00000000b

; Messages
welcome_msg db "BOOTLOADER 32-BIT MODE (640x480)", 0
disk_msg db "Reading sector 0...", 0
hex_header db "00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F", 0
keyboard_msg db "Keyboard Input: ", 0
vesa_msg db "VESA detected", 0

; Buffer for disk data
align 4
disk_buffer: times 512 db 0

; Input buffer for keyboard
input_buffer: times 64 db 0
input_position: db 0

; Cursor position data
cursor_pos_x: db 0     ; X position (0-31, representing hex digits)
cursor_pos_y: db 0     ; Y position (0-31, representing rows)
cursor_color: db 9       ; Current cursor color (0-15, VGA color)

first_row_y_offset: equ 15

; Function to display disk buffer contents
; Input: ESI = buffer address, EDI = X position, EBX = Y position
display_disk_buffer:
    pusha
    
    ; Display header
    push esi
    push edi
    push ebx
    
    mov esi, hex_header
    mov edi, 0      ; X position
    mov ebx, 0      ; Y position
    mov ah, 15      ; White color
    call print_string
    
    pop ebx
    pop edi
    pop esi
    
    ; Move below header for data
    add ebx, first_row_y_offset     ; Move Y position down
    
    ; Display the entire sector in a 16-byte per row format
    mov ecx, 512    ; Display all 512 bytes
    mov edi, 0      ; X position start (after row indicator)
    xor edx, edx    ; Counter for bytes per row
    xor ebp, ebp    ; Byte offset counter
.display_loop:
    ; Check if we need to display row number
    cmp edx, 0
    jne .skip_row_num
    
    ; Display row number (4 hex digits)
    push esi
    push edi
    push edx
    
    mov eax, ebp    ; Current offset
    mov edi, 0      ; X position for row number
    mov ah, 11      ; Yellow for row number
    call print_hex_word
    
    pop edx
    pop edi
    pop esi
    
.skip_row_num:
    ; Display the byte
    mov al, [esi]   ; Get byte from buffer
    mov ah, 11      ; Light cyan color
    
    ; Save registers
    push esi
    push edi
    push ebx
    push ecx
    push edx
    push ebp
    
    ; Convert byte to hex and display
    call print_hex_byte
    
    ; Restore registers
    pop ebp
    pop edx
    pop ecx
    pop ebx
    pop edi
    pop esi
    
    inc esi         ; Next byte
    add edi, 24     ; Move X position for next byte
    inc edx         ; Increment byte counter
    inc ebp         ; Increment overall byte counter
    
    ; Check if we need to start a new row (after 16 bytes)
    cmp edx, 16
    jne .continue_row
    
    ; Start a new row
    xor edx, edx    ; Reset byte counter
    mov edi, 0      ; Reset X position to start of data (after row indicator)
    add ebx, 10     ; Move Y position down (8 + 2 spacing)
    
.continue_row:
    loop .display_loop
    
    popa
    ret

; Function to draw cursor (underline) at specified buffer position
; Input: AL = buffer X position (0-31, each byte has 2 hex digits)
;        AH = buffer Y position (0-31, rows of buffer data)
;        BL = color (0-15, VGA color) - use 0 for erasing
draw_cursor:
    pushad
    
    ; Save input parameters
    mov cl, al      ; Save X position
    mov ch, ah      ; Save Y position
    push ebx        ; Save color on stack instead of using dl
    
    ; Calculate screen coordinates
    ; Each byte takes 24 pixels total:
    ; - First hex digit (8 pixels)
    ; - Second hex digit (8 pixels)
    ; - Spacing (8 pixels)
    
    ; First determine if we're on first or second digit of a byte
    mov bl, cl      ; Get X position
    and bl, 1       ; Isolate the lowest bit (0 = first digit, 1 = second digit)
    
    ; Calculate byte position (divide X by 2)
    movzx eax, cl
    shr eax, 1      ; Divide by 2 to get byte position
    
    ; Calculate base X position for the byte (byte_pos * 24)
    mov ecx, 24     ; 24 pixels per byte (16 for two hex digits + 8 for spacing)
    mul ecx         ; EAX = byte_pos * 24
    
    ; Add offset for the specific digit
    test bl, bl     ; Test if first or second digit
    jz .first_digit
    
    ; Second digit - add 8 pixels to X position
    add eax, 8      ; Offset for second digit
    jmp .continue_calc
    
.first_digit:
    ; No additional offset for first digit
    nop
    
.continue_calc:
    ; Add base offset for display
    add eax, 0      ; Add X base offset if needed
    mov ecx, eax    ; Store X coordinate in ECX
    
    ; Y = (buffer_y * 10) + 15 + 7 (offset + char height)
    movzx eax, ch   ; Y position
    mov edx, 10     ; 10 pixels per row
    mul edx
    add eax, first_row_y_offset ; Adjusted offset: 15 for header + 10 for first data row
    add eax, 7      ; Position below the character (correctly aligned with bottom)
    mov edx, eax    ; Store Y coordinate in EDX
    
    ; Calculate end X coordinate (X + 8 pixels, each digit is 8 pixels wide)
    mov esi, ecx    ; X1 coordinate
    add esi, 7      ; X2 = X1 + 7 (digit width - 1)
    
    ; Y2 = Y1 (single horizontal line)
    mov edi, edx
    
    ; Get color from stack and set it for drawing
    pop ebx         ; Restore color from stack
    mov al, bl      ; Move color to AL for draw_horizontal_line
    
    ; Draw the horizontal line
    call draw_horizontal_line
    
    popad
    ret

; -------------------- Keyboard Functions --------------------

; Function to check for keyboard input
check_keyboard:
    pusha
    
    ; Check if key is available
    in al, 0x64     ; Read keyboard status port
    test al, 1      ; Check if data is available (bit 0)
    jz .no_key      ; No key pressed
    
    ; Read the key
    in al, 0x60     ; Read keyboard data port
    
    ; Check if it's a key release (bit 7 set)
    test al, 0x80
    jnz .no_key     ; Ignore key releases
    
    ; Check for arrow keys for cursor movement
    cmp al, 0x48    ; Up arrow
    je .up_arrow
    cmp al, 0x50    ; Down arrow
    je .down_arrow
    cmp al, 0x4B    ; Left arrow
    je .left_arrow
    cmp al, 0x4D    ; Right arrow
    je .right_arrow
    
    ; Handle other keys with existing code
    ; Convert scan code to ASCII
    call scan_to_ascii
    
    ; If valid character, display it
    test al, al
    jz .no_key
    
    ; Display character
    mov ah, 15      ; White color
    push eax
    call print_char ; Display the character
    
    ; Store in input buffer (if there's space)
    movzx edx, byte [input_position]
    cmp edx, 63     ; Check if buffer is full
    jae .no_key     ; Skip if buffer full
    
    ; Store character
    pop eax
    mov [input_buffer + edx], al
    inc byte [input_position]
    mov byte [input_buffer + edx + 1], 0  ; Null terminator
    
    ; Advance cursor position
    add edi, 8      ; Next X position
    jmp .done
    
.up_arrow:
    ; First erase current cursor
    mov al, [cursor_pos_x]
    mov ah, [cursor_pos_y]
    xor bl, bl      ; Color 0 (black) to erase
    call draw_cursor
    
    ; Move cursor up (decrease Y)
    movzx eax, byte [cursor_pos_y]  ; Use EAX to avoid overwriting AL
    test eax, eax            ; Check if at top row
    jz .wrap_to_bottom
    dec eax
    mov [cursor_pos_y], al
    jmp .update_cursor
    
.wrap_to_bottom:
    ; Wrap to bottom row
    mov byte [cursor_pos_y], 31      ; Last row (512 bytes / 16 bytes)
    jmp .update_cursor
    
.down_arrow:
    ; First erase current cursor
    mov al, [cursor_pos_x]
    mov ah, [cursor_pos_y]
    xor bl, bl      ; Color 0 (black) to erase
    call draw_cursor
    
    ; Move cursor down (increase Y)
    movzx eax, byte [cursor_pos_y]  ; Use EAX to avoid overwriting AL
    inc eax
    cmp eax, 32             ; Check if past bottom row
    jb .set_y
    xor eax, eax            ; Wrap to top (row 0)
.set_y:
    mov [cursor_pos_y], al
    jmp .update_cursor

.left_arrow:
    ; First erase current cursor
    mov al, [cursor_pos_x]
    mov ah, [cursor_pos_y]
    xor bl, bl      ; Color 0 (black) to erase
    call draw_cursor
    
    ; Move cursor left (decrease X)
    mov al, [cursor_pos_x]
    test al, al            ; Check if at leftmost position
    jz .wrap_to_right
    dec al
    mov [cursor_pos_x], al
    jmp .update_cursor
    
.wrap_to_right:
    ; Wrap to right edge of previous row
    mov al, 31             ; Last column (16 bytes * 2 digits - 1)
    mov [cursor_pos_x], al
    
    ; Move up one row with wrap-around
    mov al, [cursor_pos_y]
    test al, al            ; Check if at top row
    jz .to_bottom_right
    dec al
    mov [cursor_pos_y], al
    jmp .update_cursor
    
.to_bottom_right:
    mov al, 31             ; Bottom row
    mov [cursor_pos_y], al
    jmp .update_cursor
    
.right_arrow:
    ; First erase current cursor
    mov al, [cursor_pos_x]
    mov ah, [cursor_pos_y]
    xor bl, bl      ; Color 0 (black) to erase
    call draw_cursor
    
    ; Move cursor right (increase X)
    mov al, [cursor_pos_x]
    inc al
    cmp al, 31             ; Check if past rightmost position (changed from 32 to 31)
    jbe .set_x             ; Changed from jb to jbe - Jump if Below or Equal
    
    ; Wrap to left edge of next row
    xor al, al             ; X = 0
    mov [cursor_pos_x], al
    
    ; Move down one row with wrap-around
    mov al, [cursor_pos_y]
    inc al
    cmp al, 32             ; Check if past bottom row
    jb .set_y_next
    xor al, al             ; Wrap to top row
.set_y_next:
    mov [cursor_pos_y], al
    jmp .update_cursor
    
.set_x:
    mov [cursor_pos_x], al
    
.update_cursor:
    ; Draw cursor at new position with current color
    mov al, [cursor_pos_x]
    mov ah, [cursor_pos_y]
    mov bl, 15       ; Set a default color (light blue) since cursor_color isn't used
    call draw_cursor
    jmp .done
    
.no_key:
    ; Wait for key to be processed
    mov ecx, 10000
.wait_loop:
    loop .wait_loop
    
.done:
    popa
    ret
    
; Convert scan code to ASCII
; Input: AL = scan code
; Output: AL = ASCII character (0 if no valid ASCII)
scan_to_ascii:
    pusha
    
    ; Simple scan code to ASCII conversion for common keys
    ; This is a simplified version
    cmp al, 0x1E
    je .key_a
    cmp al, 0x30
    je .key_b
    cmp al, 0x2E
    je .key_c
    cmp al, 0x20
    je .key_d
    cmp al, 0x12
    je .key_e
    cmp al, 0x21
    je .key_f
    cmp al, 0x22
    je .key_g
    cmp al, 0x23
    je .key_h
    cmp al, 0x17
    je .key_i
    cmp al, 0x24
    je .key_j
    cmp al, 0x25
    je .key_k
    cmp al, 0x26
    je .key_l
    cmp al, 0x32
    je .key_m
    cmp al, 0x31
    je .key_n
    cmp al, 0x18
    je .key_o
    cmp al, 0x19
    je .key_p
    cmp al, 0x10
    je .key_q
    cmp al, 0x13
    je .key_r
    cmp al, 0x1F
    je .key_s
    cmp al, 0x14
    je .key_t
    cmp al, 0x16
    je .key_u
    cmp al, 0x2F
    je .key_v
    cmp al, 0x11
    je .key_w
    cmp al, 0x2D
    je .key_x
    cmp al, 0x15
    je .key_y
    cmp al, 0x2C
    je .key_z
    cmp al, 0x39
    je .key_space
    cmp al, 0x1C
    je .key_enter
    
    ; Numbers 0-9
    cmp al, 0x0B
    je .key_0
    cmp al, 0x02
    je .key_1
    cmp al, 0x03
    je .key_2
    cmp al, 0x04
    je .key_3
    cmp al, 0x05
    je .key_4
    cmp al, 0x06
    je .key_5
    cmp al, 0x07
    je .key_6
    cmp al, 0x08
    je .key_7
    cmp al, 0x09
    je .key_8
    cmp al, 0x0A
    je .key_9
    
    ; Not a recognized key
    mov byte [esp + 28], 0   ; Set AL to 0 in the stack
    jmp .done
    
.key_a:
    mov byte [esp + 28], 'a'
    jmp .done
.key_b:
    mov byte [esp + 28], 'b'
    jmp .done
.key_c:
    mov byte [esp + 28], 'c'
    jmp .done
.key_d:
    mov byte [esp + 28], 'd'
    jmp .done
.key_e:
    mov byte [esp + 28], 'e'
    jmp .done
.key_f:
    mov byte [esp + 28], 'f'
    jmp .done
.key_g:
    mov byte [esp + 28], 'g'
    jmp .done
.key_h:
    mov byte [esp + 28], 'h'
    jmp .done
.key_i:
    mov byte [esp + 28], 'i'
    jmp .done
.key_j:
    mov byte [esp + 28], 'j'
    jmp .done
.key_k:
    mov byte [esp + 28], 'k'
    jmp .done
.key_l:
    mov byte [esp + 28], 'l'
    jmp .done
.key_m:
    mov byte [esp + 28], 'm'
    jmp .done
.key_n:
    mov byte [esp + 28], 'n'
    jmp .done
.key_o:
    mov byte [esp + 28], 'o'
    jmp .done
.key_p:
    mov byte [esp + 28], 'p'
    jmp .done
.key_q:
    mov byte [esp + 28], 'q'
    jmp .done
.key_r:
    mov byte [esp + 28], 'r'
    jmp .done
.key_s:
    mov byte [esp + 28], 's'
    jmp .done
.key_t:
    mov byte [esp + 28], 't'
    jmp .done
.key_u:
    mov byte [esp + 28], 'u'
    jmp .done
.key_v:
    mov byte [esp + 28], 'v'
    jmp .done
.key_w:
    mov byte [esp + 28], 'w'
    jmp .done
.key_x:
    mov byte [esp + 28], 'x'
    jmp .done
.key_y:
    mov byte [esp + 28], 'y'
    jmp .done
.key_z:
    mov byte [esp + 28], 'z'
    jmp .done
.key_space:
    mov byte [esp + 28], ' '
    jmp .done
.key_enter:
    mov byte [esp + 28], 13  ; CR
    jmp .done
.key_0:
    mov byte [esp + 28], '0'
    jmp .done
.key_1:
    mov byte [esp + 28], '1'
    jmp .done
.key_2:
    mov byte [esp + 28], '2'
    jmp .done
.key_3:
    mov byte [esp + 28], '3'
    jmp .done
.key_4:
    mov byte [esp + 28], '4'
    jmp .done
.key_5:
    mov byte [esp + 28], '5'
    jmp .done
.key_6:
    mov byte [esp + 28], '6'
    jmp .done
.key_7:
    mov byte [esp + 28], '7'
    jmp .done
.key_8:
    mov byte [esp + 28], '8'
    jmp .done
.key_9:
    mov byte [esp + 28], '9'
    jmp .done
    
.done:
    popa
    ret

; End of second stage boot loader 