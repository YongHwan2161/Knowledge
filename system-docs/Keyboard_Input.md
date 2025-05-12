# Keyboard Input in Protected Mode

## Overview

This document describes the keyboard input implementation in 32-bit protected mode for the bootloader. In protected mode, BIOS interrupt services are no longer available, so direct hardware access to the keyboard controller is required.

## Implementation

The keyboard input functionality is implemented in `SecondStage.asm` and includes the following components:

### Keyboard Reading

The `check_keyboard` function checks for and processes keyboard input:

```assembly
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
    
    ; Convert scan code to ASCII
    call scan_to_ascii
    
    ; If valid character, display it
    test al, al
    jz .no_key
    
    ; Display character and store in buffer
    ; ...
```

### Scan Code Conversion

The `scan_to_ascii` function converts keyboard scan codes to ASCII:

```assembly
; Input: AL = scan code
; Output: AL = ASCII character (0 if no valid ASCII)
scan_to_ascii:
    ; Conversion logic for alphanumeric keys and special characters
    ; ...
```

## Hardware Details

### Keyboard Controller Ports

| Port   | Description            |
|--------|------------------------|
| 0x60   | Data Port              |
| 0x64   | Status/Command Port    |

### Status Register Bits (0x64)

| Bit | Description              |
|-----|--------------------------|
| 0   | Output Buffer Status     |
| 1   | Input Buffer Status      |
| 2   | System Flag              |
| 3   | Command/Data             |
| 4   | Keyboard Unlocked        |
| 5   | Auxiliary Output Buffer  |
| 6   | Timeout                  |
| 7   | Parity Error             |

## Supported Keys

The current implementation supports:
- All lowercase letters (a-z)
- Numbers (0-9)
- Space
- Enter

## Limitations

- No support for uppercase letters (Shift key not implemented)
- No support for special characters
- No support for function keys
- No support for key combinations
- No key repeat functionality

## Usage

The keyboard functionality is automatically initialized and active in the main program loop. User input is displayed at the bottom of the screen and stored in the `input_buffer`.

The bootloader provides a simple input prompt:

```assembly
keyboard_msg db "Keyboard Input: ", 0
```

## Future Improvements

- Add support for uppercase letters and special characters
- Implement key repeat functionality
- Add command processing for the input
- Implement a simple command line interface
- Support for editing (backspace, delete, arrow keys) 