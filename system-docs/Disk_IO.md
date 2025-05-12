# Disk I/O in Protected Mode

## Overview

This document describes the disk I/O implementation in 32-bit protected mode for the bootloader. When transitioning from 16-bit real mode to 32-bit protected mode, BIOS services (including INT 0x13 for disk operations) are no longer available. Therefore, direct hardware access is required to perform disk operations.

## Implementation

The disk I/O functionality is implemented in `SecondStage.asm` and includes the following components:

### Disk Initialization

The `disk_init` function initializes the disk controller:

```assembly
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
```

### Reading Sectors

The `disk_read_sectors` function reads one or more sectors from disk into memory:

```assembly
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
    
    ; Read the sectors
    ; ... [implementation continues]
```

## Hardware Details

### ATA I/O Ports (Primary Controller)

| Port    | Description       |
|---------|-------------------|
| 0x1F0   | Data Port         |
| 0x1F1   | Error Register    |
| 0x1F2   | Sector Count      |
| 0x1F3   | LBA Low (0-7)     |
| 0x1F4   | LBA Mid (8-15)    |
| 0x1F5   | LBA High (16-23)  |
| 0x1F6   | Drive/Head        |
| 0x1F7   | Status/Command    |

### Status Register Bits (0x1F7)

| Bit | Description       |
|-----|-------------------|
| 7   | BSY (Busy)        |
| 6   | DRDY (Drive Ready)|
| 5   | DWF (Drive Write Fault) |
| 4   | DSC (Drive Seek Complete) |
| 3   | DRQ (Data Request) |
| 2   | CORR (Corrected Data) |
| 1   | IDX (Index) |
| 0   | ERR (Error) |

## Usage Example

To read a sector from disk:

```assembly
mov edi, buffer_address   ; Destination buffer
mov eax, 10               ; LBA address (sector 10)
mov ecx, 1                ; Read 1 sector
call disk_read_sectors
```

## Limitations

- The current implementation only supports the primary ATA controller
- Only supports 24-bit LBA addressing (up to 128 GB)
- No error handling for failed reads
- No support for writing to disk

Future improvements could include adding write support, secondary controller support, and proper error handling. 