import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../core/recording_service.dart';
import '../models/recording_item.dart';
import '../providers/recordings_provider.dart';
import 'audio_player_controls.dart';

/// List tile widget for displaying a recording item.
class RecordingListTile extends ConsumerStatefulWidget {
  final RecordingItem recording;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  const RecordingListTile({
    super.key,
    required this.recording,
    this.onTap,
    this.onLongPress,
    this.onDelete,
  });

  @override
  ConsumerState<RecordingListTile> createState() => _RecordingListTileState();
}

class _RecordingListTileState extends ConsumerState<RecordingListTile> {
  bool _showDeleteConfirm = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingsProvider);
    final isCurrentRecording = state.currentRecording?.filePath == widget.recording.filePath;
    final isPlaying = state.isPlaying && isCurrentRecording;
    final isActivelyRecording = widget.recording.session?.isActive == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isCurrentRecording
            ? AppTheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: _buildLeading(isPlaying, isActivelyRecording),
            title: _buildTitle(),
            subtitle: _buildSubtitle(),
            trailing: _buildTrailing(isPlaying),
            onTap: () {
              if (_showDeleteConfirm) {
                setState(() => _showDeleteConfirm = false);
              } else {
                ref.read(recordingsProvider.notifier).playRecording(widget.recording);
                widget.onTap?.call();
              }
            },
            onLongPress: () {
              setState(() => _showDeleteConfirm = true);
              widget.onLongPress?.call();
            },
          ),
          if (_showDeleteConfirm) _buildDeleteConfirm(),
        ],
      ),
    );
  }

  Widget _buildLeading(bool isPlaying, bool isActivelyRecording) {
    if (isActivelyRecording) {
      // Live recording indicator
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppTheme.errorRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'REC',
              style: TextStyle(
                color: AppTheme.errorRed,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (isPlaying) {
      // Playing indicator with animation
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.equalizer,
          color: AppTheme.primary,
          size: 24,
        ),
      );
    }

    // Default play icon
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.play_arrow,
        color: AppTheme.textSecondary,
        size: 24,
      ),
    );
  }

  Widget _buildTitle() {
    final chips = <Widget>[];

    // Auto-recorded badge
    if (widget.recording.autoRecorded) {
      chips.add(
        Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Auto',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            'Call #${widget.recording.callId}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (chips.isNotEmpty) ...chips,
      ],
    );
  }

  Widget _buildSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Row(
          children: [
            // Date
            Icon(
              Icons.calendar_today,
              size: 12,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              widget.recording.formattedDate,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 12),
            // Duration
            Icon(
              Icons.access_time,
              size: 12,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              widget.recording.formattedDuration,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 12),
            // File size
            Icon(
              Icons.folder,
              size: 12,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              widget.recording.formattedFileSize,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrailing(bool isPlaying) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: AppTheme.textSecondary,
      ),
      color: AppTheme.surfaceCard,
      onSelected: (value) async {
        switch (value) {
          case 'delete':
            setState(() => _showDeleteConfirm = true);
            break;
          case 'open_folder':
            await _openFolder();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: AppTheme.errorRed, size: 20),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'open_folder',
          child: Row(
            children: [
              Icon(Icons.folder_open, color: AppTheme.textSecondary, size: 20),
              SizedBox(width: 8),
              Text('Open Folder', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteConfirm() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.warning,
            color: AppTheme.errorRed,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Delete this recording?',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _showDeleteConfirm = false);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final deleted = await ref
                  .read(recordingsProvider.notifier)
                  .deleteRecording(widget.recording);
              if (deleted && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recording deleted'),
                    backgroundColor: AppTheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              widget.onDelete?.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _openFolder() async {
    try {
      final file = File(widget.recording.filePath);
      final parent = file.parent;
      // On Windows, open Explorer to the folder
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [parent.path]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [parent.path]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [parent.path]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open folder: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }
}
