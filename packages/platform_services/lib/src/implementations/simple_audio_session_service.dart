import 'package:audio_session/audio_session.dart';

import '../interfaces/audio_session_service.dart';

class SimpleAudioSessionService implements AudioSessionService {
  SimpleAudioSessionService({required AudioSessionService fallback})
    : _fallback = fallback;

  final AudioSessionService _fallback;

  @override
  Future<void> configureForVoice() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    } catch (_) {
      await _fallback.configureForVoice();
    }
  }
}
