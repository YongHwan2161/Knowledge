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

    ; Set up VGA for planar memory mode (Mode 12h)
    ; In mode 12h, we need to configure the VGA for plane writing
    ; Configure the VGA for write mode 0
    mov dx, 0x3CE   ; Graphics Controller Address Register
    mov al, 0x05    ; Mode Register
    out dx, al
    inc dx          ; Graphics Controller Data Register (0x3CF)
    mov al, 0x00    ; Write Mode 0
    out dx, al

    ; Clear the screen (black background)
    call clear_screen

    ; Draw a border around the screen
    mov ecx, 0      ; X start
    mov edx, 0      ; Y start
    mov esi, 639    ; X end
    mov edi, 479    ; Y end
    mov ah, 14      ; Yellow color
    call draw_rectangle_border

    ; Print welcome message
    mov esi, welcome_msg
    mov edi, 200    ; X position
    mov ebx, 200    ; Y position
    mov ah, 14      ; Yellow color
    call print_string

    ; Print a number
    mov eax, 12345  ; Number to print
    mov edi, 220    ; X position
    mov ebx, 240    ; Y position
    mov cl, 14      ; Yellow color
    call print_decimal

    ; Demo: Read a sector and display its content
    mov esi, disk_msg
    mov edi, 180    ; X position
    mov ebx, 280    ; Y position
    mov ah, 14      ; Yellow color
    call print_string

    ; Set up buffer to read disk data
    mov edi, disk_buffer
    mov eax, 0      ; LBA 10 (arbitrary sector to read)
    mov ecx, 1      ; Read 1 sector
    call disk_read_sectors

    ; Display first few bytes from the sector
    mov ecx, 8      ; Display 8 bytes
    mov esi, disk_buffer
    mov edi, 180    ; X position
    mov ebx, 300    ; Y position
.display_loop:
    mov al, [esi]   ; Get byte from buffer
    mov ah, 11      ; Light cyan color
    
    ; Save registers
    push esi
    push edi
    push ebx
    push ecx
    
    ; Convert byte to hex and display
    call print_hex_byte
    
    ; Restore registers
    pop ecx
    pop ebx
    pop edi
    pop esi
    
    inc esi         ; Next byte
    add edi, 24     ; Move X position for next byte
    loop .display_loop

    ; Halt the system
    cli
    hlt

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

; -------------------- Disk I/O Functions --------------------

; Function to read sectors from disk in protected mode
; Input: EAX = LBA address, ECX = number of sectors to read, EDI = buffer address
disk_read_sectors:
    pusha
    
    ; Make sure EBX contains the LBA from EAX
    mov ebx, eax
    
    ; Configure base I/O ports - using primary ATA controller
    mov dx, 0x1F6   ; Drive/Head port
    mov al, 0xE0    ; LBA mode, use primary drive
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
    
    ; Set all planes to be written to
    mov dx, 0x3C4   ; Sequencer Address Register
    mov al, 0x02    ; Map Mask Register
    out dx, al
    inc dx          ; Sequencer Data Register (0x3C5)
    mov al, 0x0F    ; Set all 4 planes
    out dx, al
    
    ; Clear the screen
    mov edi, 0xA0000  ; Video memory base
    xor eax, eax      ; Set to zero (black)
    mov ecx, 38400    ; 640*480/8 = 38400 bytes (each byte controls 8 pixels)
    rep stosd         ; Clear screen faster with dword operations
    
    popa
    ret

; Function to set a pixel in Mode 12h (640x480, 16 colors)
; Input: ECX = X, EDX = Y, AL = color (0-15)
set_pixel:
    pusha
    
    ; Calculate pixel address and bit position
    ; Pixel address = 0xA0000 + (y * 80) + (x / 8)
    ; Bit position = 7 - (x % 8)
    
    ; Calculate memory offset
    push eax
    mov eax, 80     ; 80 bytes per row
    mul edx         ; eax = y * 80
    mov edi, eax
    mov eax, ecx
    shr eax, 3      ; eax = x / 8
    add edi, eax    ; edi = y * 80 + (x / 8)
    add edi, 0xA0000 ; Add video memory base
    pop eax
    
    ; Calculate bit position in byte
    mov bl, cl      ; Use x coordinate
    and bl, 0x07    ; Get lower 3 bits (x % 8)
    mov cl, 7
    sub cl, bl      ; cl = 7 - (x % 8)
    mov bl, 1
    shl bl, cl      ; Bit mask for the pixel (using cl as shift count)
    
    ; Set up the VGA to write to the correct planes
    ; Enable the Right Plane based on the color
    mov dx, 0x3C4   ; Sequencer Address Register
    mov ah, 0x02    ; Map Mask Register
    out dx, al
    inc dx          ; Sequencer Data Register (0x3C5)
    
    ; Convert color to plane mask
    push ax
    mov ah, al
    mov al, 0       ; Start with no planes
    test ah, 1      ; Test bit 0 (blue)
    jz .skip_blue
    or al, 1        ; Set blue plane
.skip_blue:
    test ah, 2      ; Test bit 1 (green)
    jz .skip_green
    or al, 2        ; Set green plane
.skip_green:
    test ah, 4      ; Test bit 2 (red)
    jz .skip_red
    or al, 4        ; Set red plane
.skip_red:
    test ah, 8      ; Test bit 3 (intensity)
    jz .skip_intensity
    or al, 8        ; Set intensity plane
.skip_intensity:
    out dx, al      ; Set which planes to modify
    pop ax
    
    ; Read-modify-write
    mov dl, [edi]   ; Read existing byte
    or dl, bl       ; Set the bit for our pixel
    mov [edi], dl   ; Write back
    
    popa
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
    pusha
    
    ; Make sure X1 <= X2
    cmp ecx, esi
    jle .x_ordered
    xchg ecx, esi
.x_ordered:
    
    ; Draw the line
.draw_h_loop:
    push eax
    call set_pixel
    pop eax
    inc ecx
    cmp ecx, esi
    jle .draw_h_loop
    
    popa
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
; Input: AL = character, AH = color, EDI = X position, EBX = Y position
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
    
    mov eax, 0
    mov al, ah      ; Set color
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
; Input: ESI = string address, EDI = X position, EBX = Y position, AH = color
print_string:
    pusha
.loop:
    lodsb           ; Load next character to AL
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
; Input: EAX = number to print, EDI = X position, EBX = Y position, CL = color
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
db 01100011b
db 01100011b
db 01100011b
db 01101011b
db 01111111b
db 01110111b
db 01100011b
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
db 00111110b
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
disk_msg db "Reading sector 10...", 0

; Buffer for disk data
align 4
disk_buffer: times 512 db 0

; End of second stage boot loader 