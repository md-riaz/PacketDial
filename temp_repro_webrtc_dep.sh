#!/usr/bin/env bash
set -e
export PATH="/tmp/pd-bin:$PATH"
mkdir -p /tmp/pd-bin
cat >/tmp/pd-bin/python <<'EOF'
#!/usr/bin/env bash
exec /c/Windows/py.exe -3 "$@"
EOF
chmod +x /tmp/pd-bin/python
cat >/tmp/pd-bin/make <<'EOF'
#!/usr/bin/env bash
exec 'C:/Users/vm_user/Downloads/PacketDial/reference/vcpkg/downloads/tools/perl/5.42.0.1/c/bin/mingw32-make.exe' "$@"
EOF
chmod +x /tmp/pd-bin/make
cd '/c/Users/vm_user/Downloads/PacketDial/reference/engine_pjsip/pjproject/third_party/build/webrtc'
make depend