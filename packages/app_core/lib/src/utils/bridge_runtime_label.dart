import 'package:voip_bridge/voip_bridge.dart';

String bridgeRuntimeLabel(VoipBridge bridge) {
  if (bridge is ReferenceEngineVoipBridge) {
    return 'Shared native engine';
  }
  if (bridge is NativeVoipBridge) {
    return 'Legacy native bridge';
  }
  return bridge.runtimeType.toString();
}
