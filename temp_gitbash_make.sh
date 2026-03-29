set -euo pipefail
cd /c/Users/vm_user/Downloads/PacketDial/reference/engine_pjsip/pjproject
find . -name '*.mak' -o -name '*.inc' | while read -r file; do
  perl -0pi -e 's#/c/Users/vm_user/Downloads/PacketDial#C:/Users/vm_user/Downloads/PacketDial#g' "$file"
done
/c/Users/vm_user/Downloads/PacketDial/reference/vcpkg/downloads/tools/perl/5.42.0.1/c/bin/mingw32-make.exe dep
/c/Users/vm_user/Downloads/PacketDial/reference/vcpkg/downloads/tools/perl/5.42.0.1/c/bin/mingw32-make.exe -j4
