import 'dart:io';
import 'package:shonenx/shared/widgets/smart_image.dart';
import 'package:flutter/material.dart';
import 'package:shonenx/features/reader/providers/reader_prefs_provider.dart';

class ReaderImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    BoxFit fit = BoxFit.fitWidth;
    if (scaleType == ReaderScaleType.fitHeight) {
      fit = BoxFit.fitHeight;
    } else if (scaleType == ReaderScaleType.original) {
      fit = BoxFit.contain;
    }

    if (url.startsWith('/') || url.startsWith('file:')) {
      return Image.file(
        File(url.startsWith('file:') ? Uri.parse(url).toFilePath() : url),
        fit: fit,
        width: double.infinity,
        cacheWidth: 1400,
        frameBuilder: (context, child, frame, synchronous) => frame == null
            ? SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.8,
                child: const Center(child: CircularProgressIndicator()),
              )
            : child,
        errorBuilder: (context, error, stack) => SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'Page ${index + 1} is missing. Download this chapter again.',
            ),
          ),
        ),
      );
    }
    return SmartImage(
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
      errorWidget: (context, url, error) => SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image, color: Colors.grey, size: 48),
            const SizedBox(height: 8),
            Text(
              'Failed to load page ${index + 1}',
              style: TextStyle(color: textColor.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}
