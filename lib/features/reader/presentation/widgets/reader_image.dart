import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shonenx/shared/widgets/smart_image.dart';
import 'package:flutter/material.dart';
import 'package:shonenx/features/reader/providers/reader_prefs_provider.dart';

class ReaderImage extends StatefulWidget {
  final String url;
  final Map<String, String>? headers;
  final int index;
  final ReaderScaleType scaleType;
  final Color textColor;

  const ReaderImage({
    super.key,
    required this.url,
    required this.index,
    required this.scaleType,
    required this.textColor,
    this.headers,
  });

  @override
  State<ReaderImage> createState() => _ReaderImageState();
}

class _ReaderImageState extends State<ReaderImage> {
  int _attempt = 0;
  bool _retrying = false;
  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      if (widget.url.startsWith('/') || widget.url.startsWith('file:')) {
        final file = File(
          widget.url.startsWith('file:')
              ? Uri.parse(widget.url).toFilePath()
              : widget.url,
        );
        await ResizeImage.resizeIfNeeded(1400, null, FileImage(file)).evict();
      } else if (widget.url.startsWith('http')) {
        await CachedNetworkImage.evictFromCache(widget.url.split('#').first);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Could not clear this page. Tap Retry again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _attempt++;
          _retrying = false;
        });
      }
    }
  }

  Widget _failure(BuildContext context, {bool local = false}) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.8,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image_outlined, color: widget.textColor, size: 48),
        const SizedBox(height: 8),
        Text(
          local
              ? 'Page ${widget.index + 1} is missing or unreadable.'
              : 'Could not load page ${widget.index + 1}.',
          style: TextStyle(color: widget.textColor),
          textAlign: TextAlign.center,
        ),
        if (local)
          const Text(
            'If Retry does not help, download this chapter again.',
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _retrying ? null : _retry,
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.refresh),
          label: Text(_retrying ? 'Retrying…' : 'Retry page'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    final headers = widget.headers;
    final scaleType = widget.scaleType;
    BoxFit fit = BoxFit.fitWidth;
    if (scaleType == ReaderScaleType.fitHeight) {
      fit = BoxFit.fitHeight;
    } else if (scaleType == ReaderScaleType.original) {
      fit = BoxFit.contain;
    }

    if (url.startsWith('/') || url.startsWith('file:')) {
      return Image.file(
        File(url.startsWith('file:') ? Uri.parse(url).toFilePath() : url),
        key: ValueKey(_attempt),
        semanticLabel: 'Page ${widget.index + 1}',
        fit: fit,
        width: double.infinity,
        cacheWidth: 1400,
        frameBuilder: (context, child, frame, synchronous) => frame == null
            ? SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.8,
                child: const Center(child: CircularProgressIndicator()),
              )
            : child,
        errorBuilder: (context, error, stack) => _failure(context, local: true),
      );
    }
    return SmartImage(
      key: ValueKey(_attempt),
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      imageUrl: url,
      httpHeaders: headers,
      fit: fit,
      width: double.infinity,
      memCacheWidth: 1400,
      maxWidthDiskCache: 1800,
      progressIndicatorBuilder: (context, url, progress) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Center(
          child: CircularProgressIndicator(
            value: progress.progress,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => _failure(context),
    );
  }
}
