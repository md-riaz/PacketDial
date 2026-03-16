import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../models/recording_item.dart';
import '../providers/recordings_provider.dart';

class AudioPlayerControls extends ConsumerWidget {
  final RecordingItem recording;
  final VoidCallback? onClose;

  const AudioPlayerControls({
    super.key,
    required this.recording,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.album, color: c.primary, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Call #${recording.callId}',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recording.formattedDate,
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: c.textSecondary,
                    onPressed: onClose,
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _SeekBarSection(),
          ),
          const SizedBox(height: 8),
          _buildPlaybackControls(context, ref),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(recordingsProvider);
    final isPlaying = state.isPlaying;
    final isBuffering = state.isBuffering;

    if (isBuffering) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(c.primary),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.stop),
            iconSize: 28,
            color: c.textSecondary,
            onPressed: () => ref.read(recordingsProvider.notifier).stop(),
            tooltip: 'Stop',
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              color: c.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: 36,
              color: Colors.white,
              onPressed: () {
                if (isPlaying) {
                  ref.read(recordingsProvider.notifier).pause();
                } else {
                  ref.read(recordingsProvider.notifier).resume();
                }
              },
              tooltip: isPlaying ? 'Pause' : 'Play',
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.skip_next),
            iconSize: 28,
            color: c.textSecondary,
            onPressed: () {
              final duration = state.duration;
              if (duration != null) {
                ref.read(recordingsProvider.notifier).seek(duration);
              }
            },
            tooltip: 'Skip to end',
          ),
        ],
      ),
    );
  }
}

class _SeekBarSection extends ConsumerWidget {
  const _SeekBarSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(recordingsProvider);
    final duration = state.duration ?? Duration.zero;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: c.primary,
            inactiveTrackColor: c.surfaceVariant,
            thumbColor: c.primary,
            overlayColor: c.primary.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: duration.inMilliseconds > 0
                ? state.position.inMilliseconds
                    .clamp(0, duration.inMilliseconds)
                    .toDouble()
                : 0,
            min: 0,
            max: duration.inMilliseconds > 0
                ? duration.inMilliseconds.toDouble()
                : 1,
            onChanged: (value) {
              ref
                  .read(recordingsProvider.notifier)
                  .seek(Duration(milliseconds: value.toInt()));
            },
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(state.position),
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(state.duration ?? Duration.zero),
                style: TextStyle(
                  color: c.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
