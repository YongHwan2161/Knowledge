# Graphics System

## Overview

The bootloader implements a flexible graphics system that supports both VGA Mode 0x12 (640×480, 16 colors) and VESA Mode 0x101 (640×480, 256 colors). The system is designed to handle the transition between these modes while maintaining compatibility with existing code.

## VGA Mode 0x12 Implementation

### Planar Memory Model

VGA Mode 0x12 uses a complex planar memory model with 4 bit planes:

1. Each pixel's color is represented by 4 bits (allowing 16 colors)
2. These 4 bits are split across 4 different memory planes
3. To set a pixel, the system must:
   - Select the appropriate bit plane(s) using port 0x3C4/0x3C5 (Sequencer registers)
   - Write to VGA memory at address 0xA0000 + (y * 80) + (x / 8)

```assembly
; Input: ECX = X position, EDX = Y position, AL = color (0-15)
set_pixel:
    pushad                           ; Preserve all registers

    ;--- 1) Compute byte offset: offset = Y*80 + (X/8) ---
    mov   eax, edx                   ; EAX = Y
    mov   ebx, 80                    ; bytes per row in Mode 12h 
    mul   ebx                        ; EAX = Y * 80
    mov   edi, eax                   ; EDI = row offset
    mov   ebx, ecx                   ; EBX = X
    shr   ebx, 3                     ; EBX = X / 8
    add   edi, ebx                   ; EDI = Y*80 + X/8
    add   edi, 0x000A0000           ; EDI = linear video address (0xA0000+offset)

    ;--- 2) Compute intra-byte bit mask: mask = 1 << (7 − (X mod 8)) ---
    mov   ebx, ecx                   ; EBX = X
    and   ebx, 7                     ; EBX = X % 8
    mov   cl, 7
    sub   cl, bl                     ; CL = 7 − (X % 8)
    mov   bl, 1
    shl   bl, cl                     ; BL = bit mask within byte

    ;--- 3) Set up the Bit Mask Register to affect only our pixel bit ---
    mov   dx, 0x3CE                  ; Graphics Controller Index
    mov   al, 0x08                   ; Select Bit Mask Register (index 8)
    out   dx, al
    inc   dx                         ; Graphics Controller Data (0x3CF)
    mov   al, bl                     ; Only our bit will be modified
    out   dx, al
    
    ;--- 4) Save the color (AL) ---
    mov   dl, al                     ; Save color in DL
    
    ;--- 5) Configure for write mode 0 ---
    mov   dx, 0x3CE                  ; Graphics Controller Index
    mov   al, 0x05                   ; Select Mode Register (index 5)
    out   dx, al
    inc   dx                         ; Graphics Controller Data (0x3CF)
    mov   al, 0x00                   ; Mode 0 (write mode 0)
    out   dx, al

    ;--- 6) Set the color register ---
    mov   dx, 0x3CE                  ; Graphics Controller Index
    mov   al, 0x00                   ; Select Set/Reset Register (index 0)
    out   dx, al
    inc   dx                         ; Graphics Controller Data (0x3CF)
    mov   al, dl                     ; Set color
    out   dx, al

    ;--- 7) Enable Set/Reset for all planes ---
    mov   dx, 0x3CE                  ; Graphics Controller Index
    mov   al, 0x01                   ; Select Enable Set/Reset Register (index 1)
    out   dx, al
    inc   dx                         ; Graphics Controller Data (0x3CF)
    mov   al, 0x0F                   ; Enable for all planes
    out   dx, al

    ;--- 8) Write to video memory to set the pixel ---
    mov   al, [edi]                  ; Latch data (dummy read)
    mov   [edi], al                  ; Write to video memory

    popad                            ; Restore registers
    ret
```

### Color Implementation Details

The color processing in VGA Mode 0x12 is handled through several critical VGA registers:

1. **Bit Mask Register (0x08)**: Controls which bits in a byte can be modified during a write operation
2. **Set/Reset Register (0x00)**: Defines the color value (0-15) to be written
3. **Enable Set/Reset Register (0x01)**: Determines which planes will be affected by the Set/Reset register

The implementation uses write mode 0, which allows for simple, consistent color application across all graphics primitives. This approach:

- Ensures proper color setting for all text rendering functions
- Maintains consistent coloring across all graphical elements
- Simplifies the programming model for higher-level drawing functions

The `set_pixel` function implementation carefully preserves the color value across VGA programming operations:
```assembly
; set_pixel: Plot a pixel in VGA Mode 12h (640×480, 16-color planar)
; Inputs:
;   ECX = X coordinate (0..639)
;   EDX = Y coordinate (0..479)
;   AL  = color index (0..15)
set_pixel:
    pushad                           ; Preserve all registers
    
    ; Save original color from AL
    and   eax, 0x0F                  ; Ensure only valid color bits are used
    push  eax                        ; Save color on stack
    
    ; [... Address calculation code omitted ...]
    
    ; Set the color register using our saved color
    mov   dx, 0x3CE                  ; Graphics Controller Index
    mov   al, 0x00                   ; Select Set/Reset Register (index 0)
    out   dx, al
    inc   dx                         ; Graphics Controller Data (0x3CF)
    pop   eax                        ; Restore our saved color value
    out   dx, al                     ; Set color
    
    ; [... Remaining VGA programming code omitted ...]
```

This implementation ensures that the color value is properly preserved and applied to the VGA hardware, resulting in accurate color rendering for all graphical elements.

### Color Palette

VGA Mode 0x12 provides a 16-color palette, with default colors:

- 0: Black
- 1: Blue
- 2: Green
- 3: Cyan
- 4: Red
- 5: Magenta
- 6: Brown
- 7: Light Gray
- 8: Dark Gray
- 9: Bright Blue
- 10: Bright Green
- 11: Bright Cyan
- 12: Bright Red
- 13: Bright Magenta
- 14: Yellow
- 15: White

## VESA Mode 0x101 Implementation

### Linear Framebuffer Model

VESA Mode 0x101 (640×480, 256 colors) uses a linear framebuffer model:

1. Each pixel is represented by a single byte in memory
2. Pixels are arranged contiguously in memory
3. The address of a pixel at coordinate (x, y) is calculated as: `base_address + y * 640 + x`

```assembly
; Input: ECX = X position, EDX = Y position, AL = color (0-255)
set_pixel:
    ; Calculate the linear offset into the framebuffer
    ; offset = y * 640 + x
    mov eax, edx                    ; EAX = y
    mov ebx, 640                    ; Width of screen
    mul ebx                         ; EAX = y * 640
    add eax, ecx                    ; EAX = y * 640 + x
    add eax, 0xA0000                ; Add base address of framebuffer
    mov edi, eax                    ; EDI = linear address in framebuffer
    
    ; Write the color value to the pixel
    mov [edi], al                   ; Write the color value directly
    ret
```

### Expanded Color Palette

VESA Mode 0x101 supports 256 colors, allowing for much more colorful graphics. For compatibility with existing code, the first 16 colors are initialized to match the standard VGA palette.

## Mode Selection Architecture

The system now employs a hybrid approach to provide reliability while supporting both VGA and VESA modes:

1. **Bootloader (First Stage)**:
   - Uses standard VGA Mode 0x12 for guaranteed compatibility
   - Checks for VESA availability using INT 0x10, AX=0x4F00
   - Sets a flag if VESA is available for the Second Stage to use

2. **Second Stage**:
   - Starts in VGA Mode 0x12 for guaranteed compatibility
   - If VESA flag is set, can optionally switch to VESA Mode 0x101
   - Graphics API functions abstract the underlying implementation, allowing code to work with either mode

### VESA Detection Code

```assembly
check_vesa:
    mov ax, 0x4F00          ; VESA function 00h - Get VESA information
    mov di, VESA_INFO_BUFFER ; Buffer to store VESA information
    int 0x10                ; Call BIOS video services
    
    cmp ax, 0x004F          ; 0x004F = successful
    jne .no_vesa            ; If not successful, VESA not available
    
    ; VESA is available, set flag
    mov byte [VESA_AVAILABLE], 1
    ret
    
.no_vesa:
    ; VESA not available, ensure flag is clear
    mov byte [VESA_AVAILABLE], 0
    ret
```

## VGA vs VESA Comparison

| Feature | VGA Mode 0x12 | VESA Mode 0x101 |
|---------|--------------|----------------|
| Resolution | 640×480 | 640×480 |
| Colors | 16 | 256 |
| Memory Model | Planar (complex) | Linear (simple) |
| Implementation | ~50 lines of code | ~10 lines of code |
| Compatibility | Guaranteed on all systems | Not always available |
| Performance | Slower due to I/O operations | Faster direct memory access |

## Current Implementation Status

The current implementation:
1. Uses VGA Mode 0x12 in the bootloader for maximum compatibility
2. Detects VESA capability for future use
3. Second stage uses VGA Mode 0x12 but has code ready for VESA Mode 0x101
4. All graphics functions are abstracted to work with either mode

## Future Enhancements

- Fully implement VESA mode switching in the second stage
- Support higher resolution VESA modes (800×600, 1024×768)
- Add support for more complex graphics primitives (lines, rectangles, circles)
- Implement alpha blending and transparency effects using the expanded color palette
- Add hardware acceleration where available 