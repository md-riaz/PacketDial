import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../providers/recordings_provider.dart';
import '../widgets/recording_list_tile.dart';
import '../widgets/audio_player_controls.dart';
import '../widgets/title_bar.dart';
import 'app_settings_page.dart';
import '../providers/window_prefs_provider.dart';

class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(recordingsProvider);

    ref.listen<RecordingsState>(recordingsProvider, (previous, next) {
      if (next.currentRecording != null &&
          previous?.currentRecording?.filePath !=
              next.currentRecording?.filePath) {
        debugPrint(
            '[RecordingsScreen] Now playing: ${next.currentRecording?.fileName}');
      }
    });

    return Scaffold(
      body: Column(
        children: [
          TitleBar(
            title: '',
            alwaysOnTop: ref.watch(windowPrefsProvider),
            onToggleAlwaysOnTop: () =>
                ref.read(windowPrefsProvider.notifier).toggleAlwaysOnTop(),
            showBackButton: false,
          ),
          _buildHeader(c, state),
          Expanded(child: _buildContent(c, state)),
          if (state.currentRecording != null)
            AudioPlayerControls(
              recording: state.currentRecording!,
              onClose: () => ref.read(recordingsProvider.notifier).stop(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppColorSet c, RecordingsState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: c.textPrimary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recordings',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showRecordingSettings,
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Settings'),
                  style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  color: c.textPrimary,
                  onPressed: () =>
                      ref.read(recordingsProvider.notifier).loadRecordings(),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 48),
                Text(
                  '${state.recordings.length} recording${state.recordings.length != 1 ? 's' : ''}',
                  style: TextStyle(color: c.textTertiary, fontSize: 12),
                ),
                if (state.isLoading) ...[
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(c.primary),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppColorSet c, RecordingsState state) {
    if (state.isLoading && state.recordings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.recordings.isEmpty) return _buildEmptyState(c);

    return RefreshIndicator(
      onRefresh: () async =>
          ref.read(recordingsProvider.notifier).loadRecordings(),
      color: c.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: state.recordings.length,
        itemBuilder: (context, index) =>
            RecordingListTile(recording: state.recordings[index]),
      ),
    );
  }

  Widget _buildEmptyState(AppColorSet c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.surfaceCard,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mic_none, size: 64, color: c.textTertiary),
          ),
          const SizedBox(height: 24),
          Text(
            'No Recordings Yet',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recordings will appear here when you\nenable local call recording.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showRecordingSettings,
            icon: const Icon(Icons.settings),
            label: const Text('Open Recording Settings'),
            style: FilledButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordingSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AppSettingsPage(initialTab: 3)),
    );
  }
}
