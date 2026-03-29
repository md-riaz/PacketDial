import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../models/recording_item.dart';
import '../providers/recordings_provider.dart';

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
    final c = context.colors;
    final state = ref.watch(recordingsProvider);
    final isCurrentRecording =
        state.currentRecording?.filePath == widget.recording.filePath;
    final isPlaying = state.isPlaying && isCurrentRecording;
    final isActivelyRecording = widget.recording.session?.isActive == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isCurrentRecording
            ? c.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: _buildLeading(c, isPlaying, isActivelyRecording),
            title: _buildTitle(c),
            subtitle: _buildSubtitle(c),
            trailing: _buildTrailing(c, isPlaying),
            onTap: () {
              if (_showDeleteConfirm) {
                setState(() => _showDeleteConfirm = false);
              } else {
                ref
                    .read(recordingsProvider.notifier)
                    .playRecording(widget.recording);
                widget.onTap?.call();
              }
            },
            onLongPress: () {
              setState(() => _showDeleteConfirm = true);
              widget.onLongPress?.call();
            },
          ),
          if (_showDeleteConfirm) _buildDeleteConfirm(c),
        ],
      ),
    );
  }

  Widget _buildLeading(AppColorSet c, bool isPlaying, bool isActivelyRecording) {
    if (isActivelyRecording) {
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
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.equalizer, color: c.primary, size: 24),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.play_arrow, color: c.textSecondary, size: 24),
    );
  }

  Widget _buildTitle(AppColorSet c) {
    final chips = <Widget>[];
    if (widget.recording.autoRecorded) {
      chips.add(
        Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Auto',
            style: TextStyle(
              color: c.primary,
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
            style: TextStyle(
              color: c.textPrimary,
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

  Widget _buildSubtitle(AppColorSet c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.calendar_today, size: 12, color: c.textTertiary),
            const SizedBox(width: 4),
            Text(widget.recording.formattedDate,
                style: TextStyle(color: c.textTertiary, fontSize: 11)),
            const SizedBox(width: 12),
            Icon(Icons.access_time, size: 12, color: c.textTertiary),
            const SizedBox(width: 4),
            Text(widget.recording.formattedDuration,
                style: TextStyle(color: c.textTertiary, fontSize: 11)),
            const SizedBox(width: 12),
            Icon(Icons.folder, size: 12, color: c.textTertiary),
            const SizedBox(width: 4),
            Text(widget.recording.formattedFileSize,
                style: TextStyle(color: c.textTertiary, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildTrailing(AppColorSet c, bool isPlaying) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: c.textSecondary),
      color: c.surfaceCard,
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
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete, color: AppTheme.errorRed, size: 20),
              const SizedBox(width: 8),
              Text('Delete',
                  style: TextStyle(color: c.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'open_folder',
          child: Row(
            children: [
              Icon(Icons.folder_open, color: c.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text('Open Folder', style: TextStyle(color: c.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteConfirm(AppColorSet c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning, color: AppTheme.errorRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Delete this recording?',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _showDeleteConfirm = false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          FilledButton(
            onPressed: () async {
              final deleted = await ref
                  .read(recordingsProvider.notifier)
                  .deleteRecording(widget.recording);
              if (deleted && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Recording deleted'),
                    backgroundColor: c.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              widget.onDelete?.call();
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
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
