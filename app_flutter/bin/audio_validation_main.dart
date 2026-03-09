import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

String get _reportPath =>
    '${Directory.systemTemp.path}\\packetdial_audio_validation_report.json';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ValidationApp());
}

class _ValidationApp extends StatelessWidget {
  const _ValidationApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _ValidationScreen(),
    );
  }
}

class _ValidationScreen extends StatefulWidget {
  const _ValidationScreen();

  @override
  State<_ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<_ValidationScreen> {
  final List<String> _logs = <String>[];
  bool _done = false;
  bool _ok = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _runValidation();
  }

  Future<void> _runValidation() async {
    // Guarantee deterministic exit even if a plugin call hangs.
    unawaited(Future<void>.delayed(const Duration(seconds: 90), () {
      if (_finished) {
        return;
      }
      _finish(
        success: false,
        summary: 'Validation timed out after 90 seconds.',
      );
    }));

    final failures = <String>[];
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest
          .listAssets()
          .where((path) => path.startsWith('assets/sounds/'))
          .where((path) => RegExp(
                r'\.(wav|mp3|ogg|m4a)$',
                caseSensitive: false,
              ).hasMatch(path))
          .toList()
        ..sort();

      _log('Found ${assets.length} audio assets in assets/sounds');
      if (assets.isEmpty) {
        throw Exception('No audio assets found');
      }

      for (final asset in assets) {
        final player = AudioPlayer();
        try {
          _log('Testing $asset');
          await player
              .setAsset(asset)
              .timeout(const Duration(seconds: 5), onTimeout: () {
            throw TimeoutException('setAsset timeout for $asset');
          });
          await player.play().timeout(const Duration(seconds: 5), onTimeout: () {
            throw TimeoutException('play timeout for $asset');
          });

          await Future.any(<Future<void>>[
            player.playerStateStream
                .firstWhere((s) => s.processingState == ProcessingState.ready)
                .then((_) {}),
            player.playerStateStream
                .firstWhere(
                    (s) => s.processingState == ProcessingState.completed)
                .then((_) {}),
            Future<void>.delayed(const Duration(milliseconds: 600)),
          ]);

          await player.stop();
          _log('PASS $asset');
        } catch (e) {
          failures.add('$asset -> $e');
          _log('FAIL $asset -> $e');
        } finally {
          await player.dispose();
        }
      }

      if (failures.isEmpty) {
        _finish(
            success: true, summary: 'All audio assets played successfully.');
      } else {
        _finish(
          success: false,
          summary:
              '${failures.length} asset(s) failed:\n${failures.join('\n')}',
        );
      }
    } catch (e) {
      _finish(success: false, summary: 'Validation crashed: $e');
    }
  }

  void _finish({required bool success, required String summary}) {
    if (_finished) {
      return;
    }
    _finished = true;
    _log(summary);
    _writeReport(success: success, summary: summary);
    setState(() {
      _done = true;
      _ok = success;
    });
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      exit(success ? 0 : 1);
    });
  }

  void _log(String message) {
    final line = '[${DateTime.now().toIso8601String()}] $message';
    stdout.writeln(line);
    if (mounted) {
      setState(() {
        _logs.add(line);
      });
    }
  }

  void _writeReport({required bool success, required String summary}) {
    final report = <String, dynamic>{
      'success': success,
      'summary': summary,
      'generated_at': DateTime.now().toIso8601String(),
      'log_lines': _logs,
    };
    try {
      File(_reportPath).writeAsStringSync(jsonEncode(report), flush: true);
      stdout.writeln('REPORT_WRITTEN=$_reportPath');
      return;
    } catch (e) {
      stdout.writeln('REPORT_WRITE_FAILED_PRIMARY=$e');
    }
    try {
      final fallback =
          '${Directory.current.path}\\packetdial_audio_validation_report.json';
      File(fallback).writeAsStringSync(jsonEncode(report), flush: true);
      stdout.writeln('REPORT_WRITTEN=$fallback');
    } catch (e) {
      stdout.writeln('REPORT_WRITE_FAILED_FALLBACK=$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = !_done
        ? 'Running audio validation...'
        : (_ok ? 'Validation passed' : 'Validation failed');
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Validation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _done && !_ok ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                padding: const EdgeInsets.all(8),
                child: SingleChildScrollView(
                  child: Text(
                    _logs.join('\n'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
