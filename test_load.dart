import 'dart:ffi';

void main() {
  print('Attempting to load voip_core.dll...');
  try {
    final lib = DynamicLibrary.open(r'..\PacketDial-windows-x64\voip_core.dll');
    print('Loaded successfully!');
  } catch (e, st) {
    print('Error loading DLL: $e');
    print('Stacktrace: $st');
  }
}
