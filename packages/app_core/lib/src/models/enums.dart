enum SipTransport { udp, tcp, tls }

enum DtmfMode { rfc2833, sipInfo, inBand }

enum CallHistoryResult { answered, missed, rejected, busy, cancelled, failed, disconnected }

enum RegistrationState { unregistered, registering, registered, failed }

enum CallState { idle, ringing, connecting, active, held, ended }

enum CallDirection { incoming, outgoing }

enum AudioRoute { earpiece, speaker, bluetooth, headset }
