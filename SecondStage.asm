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
    mov ecx, [sector_count]      ; Read 1 sector
    call disk_read_sectors

    ; Display hex header
    call display_hex_header
    ; Display disk buffer contents
    mov esi, disk_buffer
    mov edi, 0      ; X position
    mov ebx, first_row_y_offset      ; Y position
    call display_disk_buffer
    
    ; Initialize and display cursor at the first hex digit
    mov al, 0       ; X position (first hex digit)
    mov ah, 0       ; Y position (first row)
    mov bl, 15       ; Light blue color (change as desired)
    call draw_cursor

    ; Display keyboard input message
    mov esi, keyboard_msg
    mov edi, 380      ; X position
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

; Function to write sectors to disk in protected mode
; Input: EAX = LBA address, ECX = number of sectors to write, EDI = buffer address (source)
disk_write_sectors:
    pusha
    
    mov ebx, eax    ; Save LBA from EAX to EBX
    
    ; Configure base I/O ports - using primary ATA controller
    mov dx, 0x1F6   ; Drive/Head port
    mov al, 0xE0    ; LBA mode, use primary drive (master). Top 4 bits: 1110 for LBA.
    or al, bh       ; Or with the highest 4 bits of LBA (bits 24-27), though usually 0 for <2TB disks
    out dx, al
    
    ; Send sectors count
    mov dx, 0x1F2   ; Sector count port
    mov al, cl      ; Number of sectors from ECX (low byte)
    out dx, al
    
    ; Send LBA address (low, mid, high - first 24 bits)
    mov dx, 0x1F3   ; LBA low port (0-7)
    mov al, bl      ; LBA 0-7 bits (from EBX, original EAX)
    out dx, al
    
    mov dx, 0x1F4   ; LBA mid port (8-15)
    shr ebx, 8      ; Shift original LBA to get bits 8-15
    mov al, bl      ; LBA 8-15 bits
    out dx, al
    
    mov dx, 0x1F5   ; LBA high port (16-23)
    shr ebx, 8      ; Shift original LBA again to get bits 16-23
    mov al, bl      ; LBA 16-23 bits
    out dx, al
    
    ; Send WRITE SECTORS command (0x30)
    mov dx, 0x1F7   ; Command port
    mov al, 0x30    ; WRITE SECTORS command
    out dx, al
    
    mov bl, cl      ; Save sector count for the loop (from original ECX)

.write_sector_loop:
    ; Wait for controller to be ready to accept data (BSY=0, DRQ=1)
.wait_drq:
    mov dx, 0x1F7   ; Status port
    in al, dx
    test al, 0x80   ; Test BSY bit (bit 7)
    jnz .wait_drq   ; If BSY is set, keep waiting
    test al, 0x08   ; Test DRQ bit (bit 3)
    jz .wait_drq    ; If DRQ is not set, keep waiting (error if BSY=0 and DRQ=0 for too long)
    
    ; Write one sector (256 words = 512 bytes)
    mov cx, 256     ; Word count
    mov dx, 0x1F0   ; Data port
.send_data_word:
    mov ax, [edi]   ; Get word from buffer
    out dx, ax      ; Send word to disk controller
    add edi, 2      ; Move to next word in buffer
    loop .send_data_word
    
    dec bl          ; Decrement remaining sector count
    jz .all_sectors_written ; If zero, all sectors written
    
    jmp .write_sector_loop  ; Else, write next sector

.all_sectors_written:
    ; Issue FLUSH CACHE command (0xE7) to ensure data is written to physical media
    mov dx, 0x1F7   ; Command port
    mov al, 0xE7    ; FLUSH CACHE command
    out dx, al
    
    ; Wait for flush to complete (BSY bit to clear)
.wait_flush_complete:
    mov dx, 0x1F7   ; Status port
    in al, dx
    test al, 0x80   ; Test BSY bit
    jnz .wait_flush_complete ; If busy, keep waiting

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
    
    ; Configure Graphics Controller for proper clearing
    ; First, set the Data Rotate/Function Select Register
    mov dx, 0x3CE           ; Graphics Controller Index
    mov al, 0x03            ; Data Rotate/Function Select Register
    out dx, al
    inc dx                  ; Graphics Controller Data (0x3CF)
    mov al, 0x00            ; Set rotate count to 0, operation to replace
    out dx, al
    dec dx                  ; Back to Graphics Controller Index
    
    ; Set the Set/Reset Register to 0 (black)
    mov al, 0x00            ; Set/Reset Register
    out dx, al
    inc dx                  ; Graphics Controller Data
    mov al, 0x00            ; Color 0 (black)
    out dx, al
    dec dx                  ; Back to Graphics Controller Index
    
    ; Enable Set/Reset for all planes
    mov al, 0x01            ; Enable Set/Reset Register
    out dx, al
    inc dx                  ; Graphics Controller Data
    mov al, 0x0F            ; Enable for all planes
    out dx, al
    dec dx                  ; Back to Graphics Controller Index
    
    ; Set the Bit Mask Register to enable all bits
    mov al, 0x08            ; Bit Mask Register
    out dx, al
    inc dx                  ; Graphics Controller Data
    mov al, 0xFF            ; Enable all bits (all 8 pixels in byte)
    out dx, al
    dec dx                  ; Back to Graphics Controller Index
    
    ; Set the Mode Register to write mode 0
    mov al, 0x05            ; Mode Register
    out dx, al
    inc dx                  ; Graphics Controller Data
    mov al, 0x00            ; Write mode 0
    out dx, al
    
    ; Configure Sequencer - Map Mask Register
    mov dx, 0x3C4           ; Sequencer Address Register
    mov al, 0x02            ; Map Mask Register
    out dx, al
    inc dx                  ; Sequencer Data Register (0x3C5)
    mov al, 0x0F            ; Set all 4 planes
    out dx, al
    
    ; Clear the screen
    xor eax, eax            ; Set to zero
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

; all black characters 123
db 11111111b
db 11111111b
db 11111111b
db 11111111b
db 11111111b
db 11111111b
db 11111111b
db 11111111b



; Messages
welcome_msg db "BOOTLOADER 32-BIT MODE (640x480)", 0
disk_msg db "Reading sector 0...", 0
hex_header db "00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F", 0
keyboard_msg db "Keyboard Input: ", 0
vesa_msg db "VESA detected", 0

; Buffer for disk data
align 4
disk_buffer: times 1024 db 0
sector_count: dd 2
start_line: dd 0      ; New variable to track starting line for display

; Input buffer for keyboard
input_buffer: times 64 db 0
input_position: db 0

; Cursor position data
cursor_pos_x: db 0     ; X position (0-31, representing hex digits)
cursor_pos_y: db 0     ; Y position (0-31, representing rows)
cursor_color: db 9       ; Current cursor color (0-15, VGA color)

; Offset for the first row of data
first_row_y_offset: equ 15


display_hex_header:
    pusha
    mov esi, hex_header
    mov edi, 0      ; X position
    mov ebx, 0      ; Y position
    mov ah, 15      ; White color
    call print_string
    popa
    ret

; Function to display disk buffer contents
; Input: ESI = buffer address, EDI = X position, EBX = Y position
display_disk_buffer:
    pusha    
    
    ; Calculate starting byte offset from start_line
    mov eax, [start_line]    ; Get start_line
    mov edx, 16              ; 16 bytes per row
    mul edx                  ; EAX = start_line * 16
    add esi, eax             ; Adjust buffer pointer by start_line offset
    
    ; Display 512 bytes (32 rows) starting from start_line
    mov ecx, 512    ; Display 512 bytes
    mov edi, 0      ; X position start (after row indicator)
    xor edx, edx    ; Counter for bytes per row
    mov ebp, [start_line]    ; Use start_line for row number
    imul ebp, 16    ; Convert to byte offset for row number
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
    mov ah, 11      ; Light cyan for row number
    call print_hex_word
    
    pop edx
    pop edi
    pop esi
    
.skip_row_num:
    ; Display the byte
    mov al, [esi]   ; Get byte from buffer
    mov ah, 11      ; Light cyan color for hex values
    
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
    push ebx        ; Save color on stack instead of using dl
    
    ; Calculate Y position FIRST before using eax for X calculations
    ; Y = (buffer_y * 10) + 15 + 7 (offset + char height)
    movzx edx, ah   ; Y position - use edx instead of eax
    mov ebx, 10     ; 10 pixels per row
    imul edx, ebx   ; edx = Y * 10
    add edx, first_row_y_offset ; Add offset
    add edx, 7      ; Position below the character
    push edx        ; Save Y coordinate for later
    
    ; Now calculate X position using eax
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
    
    ; Restore Y coordinate
    pop edx         ; Get saved Y coordinate
    
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

    ; Check for ESC key (Scan Code 0x01) for reboot
    cmp al, 0x01
    je .initiate_reboot
    
    ; Check if it's a key release (bit 7 set) - only if not ESC
    test al, 0x80
    jnz .no_key     ; Ignore key releases for other keys
    
    ; Check for arrow keys for cursor movement
    cmp al, 0x48    ; Up arrow
    je .up_arrow
    cmp al, 0x50    ; Down arrow
    je .down_arrow
    cmp al, 0x4B    ; Left arrow
    je .left_arrow
    cmp al, 0x4D    ; Right arrow
    je .right_arrow
    
    ; --- Key is not an arrow key or ESC --- 
    call scan_to_ascii      ; AL = ASCII char, AH = 1 if valid hex (0-9, a-f), 0 otherwise

    ; Check for 's' key to save buffer
    cmp al, 's'
    je .handle_save_key

    ; If not 's', then check if it's a valid hex digit using AH from scan_to_ascii
    test ah, ah
    jnz .process_hex_input_and_move_cursor ; If AH is non-zero (is hex), process and move

    ; --- Not 's' and not a hex digit --- 
    ; (e.g. 'g', 'h', or unrecognized scan code if AL=0 from scan_to_ascii)
    ; Do not move cursor. Just redraw it at its current position.
    jmp .update_cursor

.process_hex_input_and_move_cursor:
    ; It IS a valid hex digit. AL contains the ASCII character. AH is 1.
    call update_hex_value   ; update_hex_value uses global cursor_pos_x/y
    call move_cursor_right  ; Use the refactored function to move and redraw cursor
    jmp .done_keyboard_processing ; All processing for this key press is done

.handle_save_key:
    ; Save disk_buffer to LBA 0, 1 sector
    pusha           ; Save all general registers
    mov eax, 0      ; LBA address 0
    mov ecx, [sector_count]      ; Number of sectors to write (now uses sector_count)
    mov edi, disk_buffer ; Source buffer address
    call disk_write_sectors
    popa            ; Restore all general registers
    ; Optionally: print a "Saved!" message to the screen here
    jmp .done_keyboard_processing ; Finished handling 's' key, bypass cursor update for save

.up_arrow:
    call move_cursor_up
    jmp .done_keyboard_processing

.down_arrow:
    call move_cursor_down
    jmp .done_keyboard_processing

.left_arrow:
    call move_cursor_left
    jmp .done_keyboard_processing

.right_arrow:
    call move_cursor_right
    jmp .done_keyboard_processing
    
.update_cursor:
    ; Draw cursor at current position with default color
    mov al, [cursor_pos_x]
    mov ah, [cursor_pos_y]
    mov bl, 15       ; Light blue color
    call draw_cursor
    jmp .done_keyboard_processing
    
.no_key:
    ; Wait for key to be processed
    mov ecx, 10000
.wait_loop:
    loop .wait_loop
    
.done_keyboard_processing: ; Renamed from .done to avoid conflict
    popa
    ret

.initiate_reboot:
    ; Attempt to reboot via keyboard controller command 0xFE
    ; This command pulses the CPU reset line.
.wait_kb_controller_ready:
    in al, 0x64     ; Read keyboard controller status port
    test al, 2      ; Check if input buffer full (bit 1 should be 0)
    jnz .wait_kb_controller_ready ; Loop until controller is ready

    mov al, 0xFE    ; Command to pulse reset line
    out 0x64, al    ; Send reset command to port 0x64

    ; If the reset command somehow fails, halt the CPU indefinitely.
.hang_if_reboot_fails:
    hlt
    jmp .hang_if_reboot_fails
    
; Convert scan code to ASCII and validate hex digit
; Input: AL = scan code
; Output: AL = ASCII character (0 if no valid ASCII)
;         AH = 1 if valid hex digit, 0 otherwise
scan_to_ascii:
    pusha
    
    ; Initialize AH to 0 (not a hex digit)
    xor ah, ah
    
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
    mov byte [esp + 29], 0   ; Set AH to 0 in the stack
    jmp .done
    
.key_a:
    mov byte [esp + 28], 'a'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_b:
    mov byte [esp + 28], 'b'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_c:
    mov byte [esp + 28], 'c'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_d:
    mov byte [esp + 28], 'd'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_e:
    mov byte [esp + 28], 'e'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_f:
    mov byte [esp + 28], 'f'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_g:
    mov byte [esp + 28], 'g'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_h:
    mov byte [esp + 28], 'h'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_i:
    mov byte [esp + 28], 'i'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_j:
    mov byte [esp + 28], 'j'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_k:
    mov byte [esp + 28], 'k'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_l:
    mov byte [esp + 28], 'l'
    mov byte [esp + 29], 0   ; Not a hex digitd
    jmp .done
.key_m:
    mov byte [esp + 28], 'm'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_n:
    mov byte [esp + 28], 'n'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_o:
    mov byte [esp + 28], 'o'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_p:
    mov byte [esp + 28], 'p'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_q:
    mov byte [esp + 28], 'q'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_r:
    mov byte [esp + 28], 'r'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_s:
    mov byte [esp + 28], 's'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_t:
    mov byte [esp + 28], 't'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_u:
    mov byte [esp + 28], 'u'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_v:
    mov byte [esp + 28], 'v'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_w:
    mov byte [esp + 28], 'w'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_x:
    mov byte [esp + 28], 'x'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_y:
    mov byte [esp + 28], 'y'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_z:
    mov byte [esp + 28], 'z'
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_space:
    mov byte [esp + 28], ' '
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_enter:
    mov byte [esp + 28], 13  ; CR
    mov byte [esp + 29], 0   ; Not a hex digit
    jmp .done
.key_0:
    mov byte [esp + 28], '0'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_1:
    mov byte [esp + 28], '1'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_2:
    mov byte [esp + 28], '2'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_3:
    mov byte [esp + 28], '3'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_4:
    mov byte [esp + 28], '4'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_5:
    mov byte [esp + 28], '5'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_6:
    mov byte [esp + 28], '6'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_7:
    mov byte [esp + 28], '7'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_8:
    mov byte [esp + 28], '8'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
.key_9:
    mov byte [esp + 28], '9'
    mov byte [esp + 29], 1   ; Valid hex digit
    jmp .done
    
.done:
    popa
    ret

; Function to update hex value in buffer
; Input: AL = new hex digit (ASCII character '0'-'9', 'a'-'f')
; Uses global: cursor_pos_x, cursor_pos_y, start_line
update_hex_value:
    pusha
    push ax ; Save AL (new char). Its value will be at [esp+0] after this 32-bit push.

    ; --- Calculate target byte in disk_buffer, considering start_line ---
    ; screen_cursor_y is in [cursor_pos_y] (0-31)
    ; screen_cursor_x_nibble is in [cursor_pos_x] (0-31, for hex digits)
    ; start_line is in [start_line] (0-32, number of 16-byte lines the display is offset)

    movzx eax, byte [cursor_pos_y]  ; EAX = screen_cursor_y (0-31)
    movzx ecx, byte [cursor_pos_x]  ; ECX = screen_cursor_x_nibble (0-31)

    ; Bounds check for screen_cursor_y (0-31 valid for visible area)
    cmp eax, 32
    jae .uphv_exit ; If screen Y is out of visible range, exit

    ; Bounds check for screen_cursor_x_nibble (0-31 valid for visible area)
    cmp ecx, 32
    jae .uphv_exit ; If screen X nibble is out of visible range, exit

    ; Calculate the actual buffer row index: buffer_row_index = [start_line] + screen_cursor_y
    mov ebx, [start_line]           ; EBX = start_line (offset in 16-byte rows)
    add eax, ebx                    ; EAX now holds the true buffer_row_index from start of disk_buffer

    ; Calculate byte offset due to buffer_row: buffer_row_byte_offset = buffer_row_index * 16
    mov ebx, 16                     ; Bytes per row
    mul ebx                         ; EAX = buffer_row_index * 16. EDX holds high part (should be 0 for valid offsets).

    ; Calculate byte offset due to screen_cursor_x_nibble: buffer_col_byte_offset = screen_cursor_x_nibble / 2
    shr ecx, 1                      ; ECX = buffer_col_byte_offset (which byte column, 0-15)

    ; Total byte offset from the start of disk_buffer
    add eax, ecx                    ; EAX = (buffer_row_index * 16) + buffer_col_byte_offset

    ; Sanity check: Ensure total_byte_offset is within disk_buffer bounds (0 to 1023 for 1KB buffer)
    cmp eax, 1024                   ; Assuming disk_buffer is 1024 bytes long
    jae .uphv_exit                  ; If offset is out of bounds, exit to prevent corruption

    mov esi, disk_buffer
    add esi, eax                   ; ESI now points to the target byte in disk_buffer
    
    ; --- Rest of the function (nibble update and screen redraw) remains the same ---
    mov bl, [esi]                  ; Get current byte from disk_buffer
    
    ; Determine if we're updating high or low nibble using global screen cursor_pos_x
    mov cl, byte [cursor_pos_x]    ; Reload screen_cursor_x_nibble into CL (ECX was altered by shr)
    and cl, 1                      ; Test if odd (low nibble) or even (high nibble)
    jz .uphv_update_high_nibble
    
.uphv_update_low_nibble:
    and bl, 0xF0                   ; Clear low nibble
    mov cl, byte [esp+0]           ; Get new hex digit (original AL from argument stack)
    sub cl, '0'                    ; Convert ASCII to value
    cmp cl, 9
    jbe .uphv_low_digit
    sub cl, 'a' - '0' - 10         ; Adjust for a-f
.uphv_low_digit:
    or bl, cl                      ; Set new low nibble
    jmp .uphv_write_back
    
.uphv_update_high_nibble:
    and bl, 0x0F                   ; Clear high nibble
    mov cl, byte [esp+0]           ; Get new hex digit (original AL from argument stack)
    sub cl, '0'                    ; Convert ASCII to value
    cmp cl, 9
    jbe .uphv_high_digit
    sub cl, 'a' - '0' - 10         ; Adjust for a-f
.uphv_high_digit:
    shl cl, 4                      ; Move to high nibble
    or bl, cl                      ; Set new high nibble
    
.uphv_write_back:
    mov [esi], bl                  ; Write back to buffer. ESI points to the byte in disk_buffer.
    
    pushad ; Save all registers

    ; --- Calculate common screen coordinates ---
    ; EBX = Screen Y for the characters
    movzx ebx, byte [cursor_pos_y] ; EBX = cursor_pos_y (on-screen row 0-31 relative to data block)
    mov eax, 10                    ; 10 pixels per row (8 char height + 2 spacing used in display_disk_buffer)
    mul ebx                        ; EAX = cursor_pos_y * 10
    add eax, first_row_y_offset    ; Add base Y offset for the data block
    mov ebx, eax                   ; EBX now holds absolute screen_y_char

    ; EDI = Screen X for the first hex digit of the current byte
    ; byte_column_on_screen = cursor_pos_x / 2 (0-15)
    ; screen_x_start_of_byte_hex_pair = byte_column_on_screen * 24 pixels (24 is the step in display_disk_buffer per byte)
    movzx edi, byte [cursor_pos_x] ; EDI = cursor_pos_x (on-screen nibble column 0-31)
    shr edi, 1                     ; EDI = byte_column_on_screen (0-15)
    mov eax, edi                   ; EAX = byte_column_on_screen
    mov ecx, 24                    ; Each byte slot (XX + space) is 24 pixels wide in display_disk_buffer's main loop
    mul ecx                        ; EAX = screen_x_start_of_byte_hex_pair (relative to data area)
    mov edi, eax                   ; EDI now holds absolute screen_x for the first hex digit of the pair

    ; --- Erase the two 8x8 character cells using ASCII 123 ---
    push edi                       ; Save X for the first char (this will be the start for print_hex_byte)
    
    mov al, 123                    ; ASCII for 'all-black' character (user-defined)
    mov ah, 0                      ; Black color for print_char

    ; Erase first char cell
    ; EDI has X for first char, EBX has Y. AL has char, AH has color.
    call print_char

    ; Erase second char cell
    add edi, 8                     ; Move to X for second char cell (8 pixels wide)
    ; EBX (Y), AL (char), AH (color) are still set correctly for print_char
    call print_char

    pop edi                        ; Restore X for the first char (this is where print_hex_byte needs to start)

    ; --- Redraw the updated byte with foreground color ---
    ; ESI still points to the updated byte in disk_buffer.
    ; EDI has the screen_x_for_first_hex_digit.
    ; EBX has the screen_y_char.
    mov ah, 11                     ; Light cyan color (for print_hex_byte via print_string)
    call print_hex_byte            ; This will print the two hex digits for the byte at [esi]

    popad ; Restore all registers
    
.uphv_exit:  ; Unified exit point
    pop ax       ; Pop the AX we pushed at the start (contains original AL argument)
    popa
    ret

; Function to clear a rectangle with a specific color (Optimized Version)
; Input: ECX = X1, EDX = Y1, ESI = X2, EDI = Y2_limit, AH = color
clear_rectangle:
    pushad                  ; Save EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI

    mov bh, ah              ; BH = color (store color from input AH safely)

    ; --- Setup Graphics Controller & Sequencer for filling --- 
    ; (Uses AL, DX for port I/O)
    mov dx, 0x3CE           ; Graphics Controller Index Port
    mov al, 0x00            ; Select Set/Reset Register (Index 0)
    out dx, al
    inc dx                  ; Graphics Controller Data Port (0x3CF)
    mov al, bh              ; Load color from BH into AL
    out dx, al              ; Set the color in Set/Reset Register
    dec dx                  ; Back to Index Port (0x3CE)

    mov al, 0x01            ; Select Enable Set/Reset Register (Index 1)
    out dx, al
    inc dx                  ; Data Port
    mov al, 0x0F            ; Enable Set/Reset for all 4 planes
    out dx, al
    dec dx                  ; Back to Index Port

    mov al, 0x08            ; Select Bit Mask Register (Index 8)
    out dx, al
    inc dx                  ; Data Port
    mov al, 0xFF            ; Affect all 8 pixels in a byte
    out dx, al
    dec dx                  ; Back to Index Port

    mov al, 0x05            ; Select Mode Register (Index 5)
    out dx, al
    inc dx                  ; Data Port
    mov al, 0x00            ; Write Mode 0 (data from CPU is ignored, color from Set/Reset used)
    out dx, al              ; Function: Replace
    ; dec dx ; Not strictly necessary before switching to Sequencer

    mov dx, 0x3C4           ; Sequencer Index Port
    mov al, 0x02            ; Select Map Mask Register (Index 2)
    out dx, al
    inc dx                  ; Sequencer Data Port (0x3C5)
    mov al, 0x0F            ; Enable writes to all 4 planes
    out dx, al

    ; --- Prepare for loop --- 
    ; Parameters from stack (due to PUSHAD):
    ; Y2_limit (original EDI) is at [esp+0]
    ; X2       (original ESI) is at [esp+4]
    ; Y1       (original EDX) is at [esp+20]
    ; X1       (original ECX) is at [esp+24]

    ; Calculate start_byte_col (X1/8) -> store in ESI (now free after PUSHAD)
    mov esi, [esp+24]       ; ESI = X1 from stack
    shr esi, 3              ; ESI = X1/8 (start_byte_col)

    ; Calculate num_bytes_per_row -> store in EBX (now free)
    mov ebx, [esp+4]        ; EBX = X2 from stack
    shr ebx, 3              ; EBX = X2/8 (end_byte_col)
    sub ebx, esi            ; EBX = end_byte_col - start_byte_col
    inc ebx                 ; EBX = number of bytes per row (count for rep stosb)

    ; Initialize current_Y -> store in EBP (now free)
    mov ebp, [esp+20]       ; EBP = current_Y (starts at Y1 from stack)
    
    ; Y2_limit for the loop is [esp+0] (original EDI value)

.fill_row_loop:
    ; Calculate starting memory address for the current row's segment
    ; Target address will be in EDI for stosb
    mov eax, ebp            ; EAX = current_Y (from EBP)
    push edx                ; Save original EDX content if it was needed (mul uses EDX)
    push ecx                ; Save original ECX content (mul uses ECX if 32-bit operand)
    mov ecx, 80             ; Screen width in bytes for Mode 0x12
    mul ecx                 ; EDX:EAX = EAX * ECX (Y_offset in EAX, EDX gets high part)
    pop ecx                 ; Restore original ECX
    pop edx                 ; Restore original EDX

    add eax, esi            ; EAX = Y_offset + start_byte_col (from ESI)
    add eax, 0xA0000        ; EAX = linear video address for start of this segment
    mov edi, eax            ; EDI = destination address for stosb

    mov ecx, ebx            ; ECX = count of bytes to write (num_bytes_per_row from EBX)
    xor al, al              ; AL = value to write (can be anything, e.g. 0, as Set/Reset handles color)
    cld                     ; Clear direction flag (for stosb to increment EDI)
    rep stosb               ; Fill the bytes for the current row segment

    inc ebp                 ; Next row (current_Y++)
    cmp ebp, [esp+0]        ; Compare current_Y (EBP) with Y2_limit from stack ([esp+0])
    jle .fill_row_loop      ; If current_Y <= Y2_limit, continue loop

    popad                   ; Restore all registers to their original state
    ret

; -------------------- Cursor Movement Functions --------------------

move_cursor_up:
    pushad
    ; Erase current cursor
    mov al, [cursor_pos_x]
    mov ah, [cursor_pos_y]
    xor bl, bl      ; Color 0 (black) to erase
    call draw_cursor
    
    movzx eax, byte [cursor_pos_y]
    test eax, eax            ; Is cursor_pos_y == 0?
    jnz .mcu_move_cursor_only

    ; cursor_pos_y is 0. Try to scroll screen up.
    mov eax, [start_line]
    test eax, eax            ; Is start_line == 0?
    jz .mcu_no_action

    ; Can scroll: start_line > 0
    dec eax
    mov [start_line], eax
    
    mov ecx, 0
    mov edx, first_row_y_offset
    mov esi, 439
    mov edi, edx
    add edi, 319
    mov ah, 0
    call clear_rectangle
    
    mov esi, disk_buffer
    mov edi, 0
    mov ebx, first_row_y_offset
    call display_disk_buffer
    ; cursor_pos_y remains 0
    jmp .mcu_draw_and_exit

.mcu_move_cursor_only:
    dec byte [cursor_pos_y]
    jmp .mcu_draw_and_exit

.mcu_no_action:
    ; No change in position or start_line
.mcu_draw_and_exit:
    mov al, [cursor_pos_x]
    mov ah, [cursor_pos_y]
    mov bl, 15      ; Light blue color
    call draw_cursor
    popad
    ret

move_cursor_down:
    pushad
    ; Erase current cursor
    mov al, [cursor_pos_x]
    mov ah, [cursor_pos_y]
    xor bl, bl      ; Color 0 (black) to erase
    call draw_cursor
    
    mov al, [cursor_pos_y]
    cmp al, 31
    jl .mcd_move_cursor_y_only

    ; cursor_pos_y is 31. Try to scroll.
    mov eax, [start_line]
    cmp eax, 32 
    jae .mcd_no_action 

    inc eax
    mov [start_line], eax
    
    mov ecx, 0
    mov edx, first_row_y_offset
    mov esi, 439
    mov edi, edx
    add edi, 319
    mov ah, 0
    call clear_rectangle
        
    mov esi, disk_buffer
    mov edi, 0
    mov ebx, first_row_y_offset
    call display_disk_buffer
    ; cursor_pos_y remains 31
    jmp .mcd_draw_and_exit

.mcd_move_cursor_y_only:
    inc byte [cursor_pos_y]
    jmp .mcd_draw_and_exit

.mcd_no_action:
    ; No change
.mcd_draw_and_exit:
    mov al, [cursor_pos_x]
    mov ah, [cursor_pos_y]
    mov bl, 15      ; Light blue color
    call draw_cursor
    popad
    ret

move_cursor_left:
    pushad
    ; Erase current cursor
    mov al, [cursor_pos_x]
    mov ah, [cursor_pos_y]
    xor bl, bl      ; Color 0 (black) to erase
    call draw_cursor
    
    mov al, [cursor_pos_x]
    test al, al
    jnz .mcl_move_x_only

    ; cursor_pos_x is 0
    mov ah, [cursor_pos_y]
    test ah, ah
    jnz .mcl_wrap_to_prev_line_no_scroll

    ; cursor_pos_x is 0 AND cursor_pos_y is 0
    mov eax, [start_line]
    test eax, eax
    jz .mcl_no_action_at_all

    ; Scroll up: start_line > 0
    dec eax
    mov [start_line], eax
    mov byte [cursor_pos_x], 31
    ; cursor_pos_y remains 0
    
    mov ecx, 0
    mov edx, first_row_y_offset
    mov esi, 439
    mov edi, edx
    add edi, 319
    mov ah, 0
    call clear_rectangle
    
    mov esi, disk_buffer
    mov edi, 0
    mov ebx, first_row_y_offset
    call display_disk_buffer
    jmp .mcl_draw_and_exit

.mcl_wrap_to_prev_line_no_scroll:
    dec byte [cursor_pos_y]
    mov byte [cursor_pos_x], 31
    jmp .mcl_draw_and_exit

.mcl_move_x_only:
    dec byte [cursor_pos_x]
    jmp .mcl_draw_and_exit

.mcl_no_action_at_all:
    ; No change
.mcl_draw_and_exit:
    mov al, [cursor_pos_x]
    mov ah, [cursor_pos_y]
    mov bl, 15      ; Light blue color
    call draw_cursor
    popad
    ret

move_cursor_right:
    pushad
    ; Erase current cursor
    mov al, [cursor_pos_x]
    mov ah, [cursor_pos_y]
    xor bl, bl      ; Color 0 (black) to erase
    call draw_cursor

    mov al, [cursor_pos_x]
    cmp al, 31
    jb .mcr_move_x_only

    ; cursor_pos_x is 31
    mov byte [cursor_pos_x], 0

    mov ah, [cursor_pos_y]
    cmp ah, 31
    jb .mcr_wrap_to_next_line_no_scroll

    ; cursor_pos_x was 31 AND cursor_pos_y is 31
    mov eax, [start_line]
    cmp eax, 32
    jae .mcr_no_action_at_all

    ; Scroll down: start_line < 32
    inc eax
    mov [start_line], eax
    ; cursor_pos_x is 0, cursor_pos_y remains 31

    mov ecx, 0
    mov edx, first_row_y_offset
    mov esi, 439
    mov edi, edx
    add edi, 319
    mov ah, 0
    call clear_rectangle
    
    mov esi, disk_buffer
    mov edi, 0
    mov ebx, first_row_y_offset
    call display_disk_buffer
    jmp .mcr_draw_and_exit

.mcr_wrap_to_next_line_no_scroll:
    inc byte [cursor_pos_y]
    jmp .mcr_draw_and_exit

.mcr_move_x_only:
    inc byte [cursor_pos_x]
    jmp .mcr_draw_and_exit

.mcr_no_action_at_all:
    mov byte [cursor_pos_x], 31 ; Restore X to 31 as it was reset earlier
.mcr_draw_and_exit:
    mov al, [cursor_pos_x]
    mov ah, [cursor_pos_y]
    mov bl, 15      ; Light blue color
    call draw_cursor
    popad
    ret
    
; End of second stage boot loader 