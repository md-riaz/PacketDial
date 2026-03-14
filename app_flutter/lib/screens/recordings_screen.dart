import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../providers/recordings_provider.dart';
import '../widgets/recording_list_tile.dart';
import '../widgets/audio_player_controls.dart';
import '../widgets/title_bar.dart';
import 'app_settings_page.dart';
import '../providers/window_prefs_provider.dart';

/// Screen for viewing and playing call recordings.
class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingsProvider);

    // Listen for when a recording is selected (for debugging)
    ref.listen<RecordingsState>(
      recordingsProvider,
      (previous, next) {
        if (next.currentRecording != null &&
            previous?.currentRecording?.filePath !=
                next.currentRecording?.filePath) {
          debugPrint('[RecordingsScreen] Now playing: ${next.currentRecording?.fileName}');
        }
      },
    );

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          TitleBar(
            title: '', // Keep title in the header body instead
            alwaysOnTop: ref.watch(windowPrefsProvider),
            onToggleAlwaysOnTop: () =>
                ref.read(windowPrefsProvider.notifier).toggleAlwaysOnTop(),
            showBackButton: false, // Use the back button in the header
          ),
          // Header
          _buildHeader(state),

          // Content
          Expanded(
            child: _buildContent(state),
          ),

          // Player bottom sheet - show when there's a current recording
          if (state.currentRecording != null)
            AudioPlayerControls(
              recording: state.currentRecording!,
              onClose: () {
                ref.read(recordingsProvider.notifier).stop();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(RecordingsState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.border.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: AppTheme.textPrimary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                // Title
                const Expanded(
                  child: Text(
                    'Recordings',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Settings link
                TextButton.icon(
                  onPressed: () => _showRecordingSettings(),
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Settings'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh),
                  color: AppTheme.textPrimary,
                  onPressed: () {
                    ref.read(recordingsProvider.notifier).loadRecordings();
                  },
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Summary row
            Row(
              children: [
                const SizedBox(width: 48), // Align with content after back button
                Text(
                  '${state.recordings.length} recording${state.recordings.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
                if (state.isLoading) ...[
                  const SizedBox(width: 16),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primary),
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

  Widget _buildContent(RecordingsState state) {
    if (state.isLoading && state.recordings.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.recordings.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(recordingsProvider.notifier).loadRecordings();
      },
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100), // Space for player
        itemCount: state.recordings.length,
        itemBuilder: (context, index) {
          final recording = state.recordings[index];
          return RecordingListTile(
            recording: recording,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mic_none,
              size: 64,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Recordings Yet',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Recordings will appear here when you\nenable local call recording.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showRecordingSettings,
            icon: const Icon(Icons.settings),
            label: const Text('Open Recording Settings'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordingSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AppSettingsPage(initialTab: 3),
      ),
    );
  }
}
