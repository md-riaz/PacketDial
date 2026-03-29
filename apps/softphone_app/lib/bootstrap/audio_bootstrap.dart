import 'package:platform_services/platform_services.dart';

import 'app_services.dart';

class AudioBootstrap {
  static Future<void> configure([AudioSessionService? service]) async {
    await (service ?? AppServices.instance.audioSession).configureForVoice();
  }
}
