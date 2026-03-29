#!/usr/bin/env bash
set -e
mkdir -p /tmp/pd-bin
cat >/tmp/pd-bin/make <<'EOF'
#!/usr/bin/env bash
exec 'C:/Users/vm_user/Downloads/PacketDial/reference/vcpkg/downloads/tools/perl/5.42.0.1/c/bin/mingw32-make.exe' "$@"
EOF
chmod +x /tmp/pd-bin/make
export PATH="/tmp/pd-bin:$PATH"
cd '/c/Users/vm_user/Downloads/PacketDial/reference/engine_pjsip/pjproject'
make clean
make -j4