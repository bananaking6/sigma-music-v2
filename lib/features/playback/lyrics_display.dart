import 'package:flutter/material.dart';
import '../../core/models/lyrics.dart';

/// Widget to display song lyrics.
class LyricsDisplay extends StatefulWidget {
  const LyricsDisplay({
    super.key,
    required this.lyrics,
    this.onClose,
  });

  final Lyrics? lyrics;
  final VoidCallback? onClose;

  @override
  State<LyricsDisplay> createState() => _LyricsDisplayState();
}

class _LyricsDisplayState extends State<LyricsDisplay> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = widget.lyrics;

    if (lyrics == null) {
      return Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Lyrics'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No lyrics found',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final plainText = lyrics.plainText;
    final syncedLines = lyrics.syncedLines;

    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: const Text('Lyrics'),
            automaticallyImplyLeading: false,
            actions: [
              if (lyrics.provider != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      'From ${lyrics.provider}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Expanded(
            child: syncedLines.isNotEmpty
                ? _SyncedLyricsView(
                    lines: syncedLines,
                    scrollController: _scrollController,
                  )
                : plainText != null && plainText.isNotEmpty
                    ? _PlainLyricsView(
                        text: plainText,
                        scrollController: _scrollController,
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No lyrics available',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _PlainLyricsView extends StatelessWidget {
  const _PlainLyricsView({
    required this.text,
    required this.scrollController,
  });

  final String text;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      scrollPhysics: const BouncingScrollPhysics(),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.8,
          ),
    );
  }
}

class _SyncedLyricsView extends StatelessWidget {
  const _SyncedLyricsView({
    required this.lines,
    required this.scrollController,
  });

  final List<LyricsLine> lines;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatDuration(line.start),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
