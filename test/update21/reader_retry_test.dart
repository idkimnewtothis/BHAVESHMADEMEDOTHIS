import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shonenx/features/reader/presentation/widgets/reader_image.dart';
import 'package:shonenx/features/reader/providers/reader_prefs_provider.dart';

void main() {
  testWidgets(
    'failed offline page retries after file is restored without leaving chapter',
    (tester) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('page-retry-');
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File('${dir.path}/page.png');
        await file.writeAsString('incomplete page');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ReaderImage(
                  url: file.path,
                  index: 2,
                  scaleType: ReaderScaleType.fitWidth,
                  textColor: Colors.white,
                ),
              ),
            ),
          ),
        );
        final error = find.text('Page 3 is missing or unreadable.');
        for (var i = 0; i < 100 && error.evaluate().isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
        expect(error, findsOneWidget);
        expect(
          tester.getSize(find.byType(FilledButton)).height,
          greaterThanOrEqualTo(48),
        );
        await File('test/fixtures/reader-page.png').copy(file.path);
        await tester.tap(find.text('Retry page'));
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          final raw = find.byType(RawImage);
          if (raw.evaluate().isNotEmpty &&
              tester.widget<RawImage>(raw).image != null) {
            break;
          }
        }
        expect(error, findsNothing);
        expect(find.byType(RawImage), findsOneWidget);
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      });
    },
  );
}
