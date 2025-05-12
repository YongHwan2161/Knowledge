# Font System

## Overview

The bootloader includes a bitmap font system that allows rendering of text in graphics mode. The font is an 8x8 pixel monospaced font that supports ASCII characters from 32 (space) to 122 (lowercase 'z'), including special characters, numbers, uppercase and lowercase letters.

## Font Data Structure

Each character in the font is represented by 8 bytes, where each byte corresponds to one row of pixels in the character. Within each byte, each bit represents one pixel in that row, with a 1 meaning the pixel should be drawn and a 0 meaning the pixel should be left blank.

Example for the letter 'A':
```
00111100b  --OOOO--
01100110b  -OO--OO-
01100110b  -OO--OO-
01111110b  -OOOOOO-
01100110b  -OO--OO-
01100110b  -OO--OO-
01100110b  -OO--OO-
00000000b  --------
```

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
; Input: AL = character, AH = color, EDI = X position, EBX = Y position
print_char:
    ; Implementation details...
```

### String Rendering

The `print_string` function renders a null-terminated string:

```assembly
; Input: ESI = string address, EDI = X position, EBX = Y position, AH = color
print_string:
    ; Implementation details...
```

## Color Support

The font system supports 16 colors (4-bit color values) through the VGA color registers. The color is specified in the AH register when calling the print functions.

Common color values:
- 0: Black
- 1: Blue
- 2: Green
- 4: Red
- 7: Light gray
- 15: White
- 14: Yellow
- 11: Cyan

## Limitations

- Fixed 8x8 pixel size for all characters
- No support for text attributes like bold or italic
- No variable width characters
- Limited to the 16-color palette of VGA mode 12h 