#!/bin/bash
# Must be run from inside FLINT.framework directory

echo "🔧 Fixing FLINT.framework symlinks..."

# Remove broken directories/symlinks  
rm -rf Headers Modules Resources FLINT

# Create correct symlinks at framework root
ln -sf Versions/A/Headers Headers
ln -sf Versions/A/Modules Modules  
ln -sf Versions/A/Resources Resources
ln -sf Versions/A/FLINT FLINT

# Fix Current version symlink
cd Versions
rm -f Current  
ln -sf A Current
cd ..

echo "✅ Framework symlinks fixed!"

# Verify the fix
echo "📁 Checking Headers directory:"
ls -la Headers/
