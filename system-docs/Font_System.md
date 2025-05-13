# Font System

## Overview

The bootloader uses a custom bitmap font system to display text in graphics mode. This system is designed to be compatible with both VGA and VESA graphics modes, providing a consistent user interface.

## Font Data

The font data is stored as an 8x8 bitmap font, supporting ASCII characters from space (32) to tilde (126). Each character is represented by 8 bytes, where each byte represents one row of the character with bits set for pixels that should be drawn.

```assembly
; Example font data for letter 'A'
db 00111100b  ; Row 1: ..####..
db 01100110b  ; Row 2: .##..##.
db 01100110b  ; Row 3: .##..##.
db 01111110b  ; Row 4: .######.
db 01100110b  ; Row 5: .##..##.
db 01100110b  ; Row 6: .##..##.
db 01100110b  ; Row 7: .##..##.
db 00000000b  ; Row 8: ........
```

## Text Rendering Functions

The system provides several functions for text rendering:

1. `print_char` - Print a single character
2. `print_string` - Print a null-terminated string
3. `print_decimal` - Print a decimal number
4. `print_hex_byte` - Print a byte as hexadecimal
5. `print_hex_word` - Print a word as hexadecimal

### Color Handling

Color information is passed to text rendering functions in different registers depending on the function:

- `print_char` and `print_string`: Color is passed in the AH register (0-15)
- `print_decimal`: Color is passed in the CL register (0-15)

The color value corresponds to the standard VGA 16-color palette:

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

### Color Implementation Details

For text rendering, the color value is passed from the high-level text functions down to the `set_pixel` function:

1. The caller sets the color in AH for `print_char`/`print_string` or CL for `print_decimal`
2. The function preserves this color value and passes it to the `set_pixel` function directly
3. The `set_pixel` function uses VGA hardware registers to apply the color correctly across all bitplanes

```assembly
; Example of color passing in print_char
; Input: AL = character, AH = color (0-15)
mov al, 'A'        ; Character to print
mov ah, 14         ; Yellow color
call print_char

; Inside print_char function, the color is passed to set_pixel:
mov al, ah         ; Transfer color from AH to AL for set_pixel
call set_pixel
```

## Usage Examples

```assembly
; Print a string in yellow
mov esi, hello_msg   ; Message to print
mov edi, 100         ; X position
mov ebx, 100         ; Y position
mov ah, 14           ; Yellow color
call print_string

; Print a number in cyan
mov eax, 12345       ; Number to print
mov edi, 100         ; X position
mov ebx, 120         ; Y position
mov cl, 3            ; Cyan color
call print_decimal

; Print a byte in green
mov esi, data_byte   ; Byte to print
mov edi, 100         ; X position
mov ebx, 140         ; Y position
mov ah, 2            ; Green color
call print_hex_byte
```

## Special Considerations

1. The font bitmap is designed for a specific aspect ratio and may appear stretched in some graphics modes
2. Text wrapping is automatically handled for `print_string` when approaching the screen edge
3. For better readability, a 1-pixel spacing is added between rows when wrapping text
4. The system does not currently support variable width fonts or proportional spacing

## Future Enhancements

- Support for variable width fonts
- Support for multiple font sizes
- Support for font styles (bold, italic)
- Support for Unicode characters
- Support for text background colors
- Support for text attributes (underline, strikethrough)

## Character Support

The font includes the following character sets:
- ASCII 32-47: Space and special characters (space, !, ", #, $, %, &, ', (, ), *, +, ,, -, ., /)
- ASCII 48-57: Numeric digits (0-9)
- ASCII 58-64: Special characters (:, ;, <, =, >, ?, @)
- ASCII 65-90: Uppercase letters (A-Z)
- ASCII 91-96: Special characters ([, \, ], ^, _, `)
- ASCII 97-122: Lowercase letters (a-z)

## Rendering Functions

### Character Rendering

The `print_char` function in SecondStage.asm renders a single character:

```assembly
; Input: AL = character, AH = color (0-15), EDI = X position, EBX = Y position
; IMPORTANT: Color must be in AH, not AL
print_char:
    ; Implementation details...
```

### String Rendering

The `print_string` function renders a null-terminated string:

```assembly
; Input: ESI = string address, EDI = X position, EBX = Y position, AH = color (0-15)
; IMPORTANT: Color must be in AH, not AL
print_string:
    ; Implementation details...
```

### Decimal Number Rendering

The `print_decimal` function renders a decimal number:

```assembly
; Input: EAX = number to print, EDI = X position, EBX = Y position, CL = color (0-15)
; IMPORTANT: Color must be in CL, not AL or AH
print_decimal:
    ; Implementation details...
```

## Color Support

The font system uses VGA Mode 0x12 (640×480, 16 colors) which employs a complex planar memory model. This implementation properly handles the VGA memory architecture to ensure colors display correctly.

### Standard 16-Color Palette

The system uses the standard VGA 16-color palette:

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

### Important: Register Usage for Colors

Each text rendering function expects the color in a different register:
- `print_char`: Color in **AH** register
- `print_string`: Color in **AH** register
- `print_decimal`: Color in **CL** register

This difference is by design but requires careful attention when calling these functions.

## VGA Planar Memory Implementation

The system handles the complex VGA planar memory model when rendering text. For each character:

1. The font bitmap is retrieved based on the ASCII value
2. Each row of the character is rendered pixel by pixel
3. For each pixel, the system:
   - Calculates the memory address and bit position in VGA memory
   - Handles the complex VGA planar model by setting the appropriate bit planes
   - Writes to memory with the specified color

This implementation ensures proper color rendering without the purple artifacts that previously occurred due to improper plane selection and bit manipulation.

## Future VESA Support

The system is designed with future support for VESA Mode 0x101 (640×480, 256 colors) in mind. This would provide several advantages:

1. Simpler pixel addressing with a linear framebuffer model
2. Support for up to 256 colors
3. Better performance due to fewer I/O operations
4. More reliable color rendering

Currently, the bootloader checks for VESA availability but continues to use VGA Mode 0x12 for maximum compatibility.

## Limitations

The font system has the following limitations:
- Fixed 8x8 pixel size for all characters
- No support for text attributes like bold or italic
- No variable width characters
- Limited to 16 colors in the current VGA implementation 