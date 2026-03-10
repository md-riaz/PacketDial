import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Provides centralized path resolution for the application,
/// supporting portable mode for desktop platforms.
class PathProviderService {
  PathProviderService._();
  static final PathProviderService instance = PathProviderService._();

  /// Gets the directory where application data should be stored.
  /// For portable builds (release mode on desktop), this is a 'data' folder
  /// alongside the executable.
  /// For development (debug mode), it uses standard app support directory.
  Future<Directory> getDataDirectory() async {
    if (kReleaseMode &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final dataDir = Directory(p.join(exeDir.path, 'data'));
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }
      return dataDir;
    } else {
      // Fallback for debug mode or non-desktop platforms
      final dir = await getApplicationSupportDirectory();
      return dir;
    }
  }
}
