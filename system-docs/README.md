# Bootloader System Documentation

This folder contains technical documentation for various components of the bootloader.

## Available Documentation

- [Disk I/O in Protected Mode](Disk_IO.md): Documentation for disk I/O operations implemented in 32-bit protected mode.
- [Font System](Font_System.md): Documentation for the bitmap font rendering system.
- [Graphics System](Graphics_System.md): Documentation for the graphics implementation, covering both VGA and VESA modes.
- [Keyboard Input](Keyboard_Input.md): Documentation for keyboard input handling in protected mode.
- [Hex Editor](Hex_Editor.md): Documentation for the hex editor functionality including cursor navigation and display.

## Bootloader Overview

The bootloader consists of two stages:

1. **First Stage** (`BootLoader.asm`): A 16-bit real mode bootloader that sets up the environment, enables A20 line, loads GDT, and transitions to 32-bit protected mode.

2. **Second Stage** (`SecondStage.asm`): A 32-bit protected mode program that initializes the system, sets up graphics, and provides various system services like disk I/O and text rendering.

The bootloader currently supports:
- Graphics Mode: 640x480 with 16 colors (VGA Mode 0x12)
- Text rendering with a bitmap font (supports full ASCII set from 32-122, including lowercase letters)
- Disk I/O in protected mode
- Basic number display
- Keyboard input in protected mode
- Hex editor with cursor-based navigation and hexadecimal display
- VGA color support for UI elements
- VESA capability detection for future graphics extensions

## Architecture

The bootloader follows a traditional design:
- The BIOS loads the first stage at address 0x7C00
- The first stage loads the second stage at address 0x1000
- The second stage initializes protected mode and provides system services 