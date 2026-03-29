set -euo pipefail
mkdir -p /tmp/pd-bin
cat > /tmp/pd-bin/python <<'EOF'
#!/usr/bin/env bash
/c/Windows/py.exe -3 "$@"
EOF
chmod +x /tmp/pd-bin/python
cat > /tmp/pd-bin/make <<'EOF'
#!/usr/bin/env bash
/c/Users/vm_user/Downloads/PacketDial/reference/vcpkg/downloads/tools/perl/5.42.0.1/c/bin/mingw32-make.exe "$@"
EOF
chmod +x /tmp/pd-bin/make
cd /c/Users/vm_user/Downloads/PacketDial/reference/engine_pjsip/pjproject
tr -d '\r' < ./configure-android > /tmp/packetdial-configure-android
chmod +x /tmp/packetdial-configure-android
cp /c/Users/vm_user/Downloads/PacketDial/native/voip_core/android/pjproject_config_site.h pjlib/include/pj/config_site.h
export PATH=/tmp/pd-bin:$PATH
export ANDROID_NDK_ROOT=/c/Android/Sdk/ndk/28.2.13676358
export TARGET_ABI=arm64-v8a
/tmp/packetdial-configure-android --use-ndk-cflags
find . -name '*.mak' -o -name '*.inc' | while read -r file; do perl -0pi -e 's#/c/Users/vm_user/Downloads/PacketDial#C:/Users/vm_user/Downloads/PacketDial#g' "$file"; done
make dep
make -j4
