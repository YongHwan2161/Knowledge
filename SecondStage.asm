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
    mov edi, 20      ; X position
    mov ebx, 20      ; Y position
    mov ah, 15       ; White color
    call print_string

    ; Print a number
    mov eax, 12345    ; Number to print
    mov edi, 20       ; X position
    mov ebx, 60       ; Y position
    mov cl, 14        ; Yellow color
    call print_decimal

    ; Halt the system
    cli
    hlt

; Function to clear the screen
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

; Messages
welcome_msg db "BOOTLOADER 32-BIT MODE (640x480)", 0

; End of second stage boot loader 