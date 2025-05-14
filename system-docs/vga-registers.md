# VGA Register Documentation

## VGA Register Ports
- **0x3C4**: Sequencer Address Register
- **0x3C5**: Sequencer Data Register
- **0x3CE**: Graphics Controller Index
- **0x3CF**: Graphics Controller Data

## Important VGA Registers for Screen Clearing

### Sequencer Registers
- **0x02** (Map Mask Register): Controls which color planes are written to
  - Value `0x0F` enables all four planes

### Graphics Controller Registers
- **0x00** (Set/Reset Register): Value to be written to planes with Enable Set/Reset
  - Value `0x00` for black
  - Value `0xFF` for white
  
- **0x01** (Enable Set/Reset Register): Controls which planes use Set/Reset value
  - Value `0x0F` enables all four planes
  
- **0x03** (Data Rotate/Function Select Register): Controls data processing
  - Value `0x00` sets no rotation, normal operation
  
- **0x05** (Mode Register): Sets operating mode for the graphics controller
  - Value `0x00` for write mode 0 (use Set/Reset)

- **0x08** (Bit Mask Register): Controls which bits in a byte are modified
  - Value `0xFF` enables all bits (all 8 pixels per byte)
  - If improperly set, can cause patterns like only every 8th pixel being modified

## Screen Clearing Process
1. Configure Graphics Controller registers to use Set/Reset with value 0 (black)
2. Configure Bit Mask Register to allow writing to all bits (0xFF)
3. Configure Map Mask Register to write to all planes
4. Fill video memory with zeros using `stosd` instruction

## Common Issues
- If only the Map Mask Register is set without configuring Graphics Controller registers, writing zeros may result in white screen instead of black
- If the Bit Mask Register (0x08) is not set to 0xFF, only certain bits/pixels will be modified (e.g., every 8th pixel)
- Complete setup of the VGA registers is essential for proper color rendering in planar mode 