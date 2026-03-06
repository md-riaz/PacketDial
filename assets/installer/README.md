# Installer Icon

Place a 256x256 ICO file named `icon.ico` in this directory.

## Requirements

- Format: `.ico` (Windows icon format)
- Size: 256x256 pixels (or multi-resolution with 256x256 as largest)
- Colors: 32-bit with alpha channel

## How to Create

### Option 1: Convert from PNG
1. Create/export your logo as 256x256 PNG
2. Use an online converter:
   - https://convertio.co/png-ico/
   - https://www.icoconverter.com/
3. Save as `icon.ico` in this folder

### Option 2: Use GIMP
1. Open your logo in GIMP
2. Image → Scale Image → 256x256
3. File → Export As → `icon.ico`
4. Select "Windows Icon" format

### Option 3: Use Inkscape
1. Open SVG logo in Inkscape
2. Set document size to 256x256
3. File → Save As → PNG
4. Convert PNG to ICO using online tool

## Note

If no icon is provided, the installer will use the default Inno Setup icon.
The application executable will use the Flutter default icon.
