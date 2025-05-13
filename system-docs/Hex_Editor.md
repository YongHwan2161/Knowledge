# Hex Editor Functionality

## Overview

This document describes the hex editor implemented in the bootloader's second stage. The hex editor allows users to view and navigate through memory buffer contents in hexadecimal format, with future support for editing the displayed values.

## Key Components

### Hex Display

The hex editor uses the `print_hex_word` function to display buffer data in hexadecimal format:

```assembly
; Function to print a word (2 bytes) in hexadecimal
; Input: AX = word to print
print_hex_word:
    push ax
    push bx
    push cx
    
    mov bx, ax          ; Save the word
    mov ch, 4           ; Counter for 4 hex digits
    
    .print_digit:
        rol bx, 4       ; Rotate left to get the leftmost digit
        mov al, bl      ; Get the digit
        and al, 0Fh     ; Mask out the high nibble
        
        ; Convert to ASCII
        cmp al, 10
        jl .decimal
        add al, 'A' - 10  ; Convert A-F
        jmp .print
        
    .decimal:
        add al, '0'     ; Convert 0-9
        
    .print:
        call print_char
        
        dec ch
        jnz .print_digit
    
    pop cx
    pop bx
    pop ax
    ret
```

### Cursor System

The hex editor implements a cursor system to navigate through the displayed hex values:

1. **Cursor Drawing Functions**:
   - `draw_cursor`: Draws an underline beneath a hex digit at the specified position
   - `erase_cursor`: Erases a previously drawn cursor

2. **Cursor Position Tracking**:
   - `cursor_pos_x`: Horizontal position of the cursor
   - `cursor_pos_y`: Vertical position of the cursor
   - Cursor positioning calculations account for the spacing of hex values (each byte uses 24 pixels: 8 for first digit, 8 for second digit, 8 for spacing)

3. **Color Support**:
   - The cursor supports different colors using VGA Mode 0x12's 16-color palette
   - A `cursor_color` variable tracks the current cursor color (0-15)

```assembly
; Draw cursor (underline) at the current cursor position
; Input: BL = color (0-15)
draw_cursor:
    pusha
    ; Calculate screen position based on cursor_pos_x and cursor_pos_y
    ; Draw an underline beneath the hex digit
    ; ...
    popa
    ret

; Erase cursor from the current position
erase_cursor:
    pusha
    ; Clear the underline at the current cursor position
    ; ...
    popa
    ret
```

### Keyboard Navigation

The hex editor supports navigation through the buffer using arrow keys:

```assembly
; Handle arrow key navigation
keyboard_navigation:
    ; Check for arrow key scan codes
    cmp al, SCAN_UP_ARROW
    je .move_up
    cmp al, SCAN_DOWN_ARROW
    je .move_down
    cmp al, SCAN_LEFT_ARROW
    je .move_left
    cmp al, SCAN_RIGHT_ARROW
    je .move_right
    
    ; Move cursor based on key press
    ; ...
```

Features include:
- Up/down/left/right movement
- Proper wrapping at screen edges
- Automatic scrolling when reaching the edge of the visible buffer

## VGA Implementation Details

The hex editor uses VGA Mode 0x12 (640x480 with 16 colors) for display. Key implementation details:

1. **Planar Memory Architecture**:
   - VGA memory is organized in planes, requiring special handling for pixel manipulation
   - The implementation properly selects bit planes and sets appropriate registers to ensure correct color rendering
   - Bit masking operations are used to set specific pixels within a byte

2. **Color Handling**:
   - Support for 16 colors (0-15) for the cursor and text
   - Specific color register configuration to prevent the "purple artifact" issue previously encountered

3. **Performance Optimizations**:
   - Optimized memory access patterns to reduce the number of VGA register writes
   - Batched updates where possible to improve rendering speed

## Current Limitations

- Limited to viewing buffer data (editing capabilities not yet implemented)
- Fixed buffer size
- No scrolling beyond buffer boundaries
- Limited to hexadecimal display (no ASCII view)
- Restricted to 16 colors in the current VGA implementation

## Future Enhancements

Planned enhancements for the hex editor include:
- Editing capabilities for modifying buffer contents
- Split-screen view with ASCII representation alongside hex values
- Extended color coding for different data types when VESA mode is fully implemented
- Support for saving changes back to disk
- Multiple buffers and navigation between buffers
- Potential upgrade to VESA Mode 0x101 for simplified pixel handling and more colors 