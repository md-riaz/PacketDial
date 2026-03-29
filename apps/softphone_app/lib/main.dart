import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/softphone_app.dart';
import 'bootstrap/audio_bootstrap.dart';
import 'bootstrap/notifications_bootstrap.dart';
import 'bootstrap/plugin_bootstrap.dart';
import 'bootstrap/window_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowBootstrap.maybeInit();
  await PluginBootstrap.initialize();
  await AudioBootstrap.configure();
  await NotificationsBootstrap.initialize();
  runApp(const ProviderScope(child: SoftphoneApp()));
}
