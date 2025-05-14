# Register Usage in SecondStage.asm

## Keyboard Input Handling (check_keyboard)
- AX: Used for both cursor position and input character
  - AH: Cursor Y position (preserved during hex input validation)
  - AL: Input character from keyboard
- BX: Used for cursor color
  - BL: Color value (0 for erase, 15 for light blue)
- CX: Used for cursor X position in update_hex_value
  - CL: Cursor X position
- DX: Used for port I/O
  - DL: Port number for keyboard status/input

## Important Register Preservation Notes
1. During hex input validation:
   - AX (containing cursor Y in AH and input char in AL) is saved to stack
   - Restored after validation to preserve cursor position
   - This ensures cursor Y position is not lost during hex digit checks

// ... existing code ... 