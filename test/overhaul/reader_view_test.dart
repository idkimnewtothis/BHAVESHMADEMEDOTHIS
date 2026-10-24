import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shonenx/features/reader/presentation/widgets/reader_webtoon_view.dart';
import 'package:shonenx/features/reader/presentation/widgets/reader_page_view.dart';
import 'package:shonenx/features/reader/providers/reader_prefs_provider.dart';
import 'package:shonenx/source_engine/models/chapter_page.dart';

void main() {
  testWidgets('webtoon keeps scroll position through parent page updates', (
    tester,
  ) async {
    const url =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGQAAAEsCAIAAAC6/IG2AAACdUlEQVR4nO3QQQ0AIAzAwPk3DRbWFyG5U9B0DmvzOuAnZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgUX2kVE8xfiPtUAAAAASUVORK5CYII=';
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('reader-fixture-'),
    );
    addTearDown(() => directory!.deleteSync(recursive: true));
    final file = File('${directory!.path}/page.png');
    await tester.runAsync(
      () => file.writeAsBytes(base64Decode(url.split(',').last)),
    );
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.runAsync(
      () => precacheImage(
        ResizeImage.resizeIfNeeded(1400, null, FileImage(file)),
        tester.element(find.byType(Scaffold)),
        onError: (error, stack) =>
            throw StateError('Fixture decode failed: $error'),
      ),
    );
    final pages = List.generate(8, (_) => ChapterPage(url: file.path));
    final key = GlobalKey<ReaderWebtoonViewState>();
    var page = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, set) {
            rebuild = set;
            return ReaderWebtoonView(
              key: key,
              pages: pages,
              initialPage: page,
              scaleType: ReaderScaleType.fitWidth,
              textColor: Colors.white,
              onPageChanged: (value) => set(() => page = value),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    key.currentState!.jumpToPage(4);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final list = tester.widget<ScrollablePositionedList>(
      find.byType(ScrollablePositionedList),
    );
    expect(
      list.itemPositionsNotifier!.itemPositions.value.any(
        (p) => p.index == 4 && p.itemLeadingEdge < 1 && p.itemTrailingEdge > 0,
      ),
      isTrue,
      reason: list.itemPositionsNotifier!.itemPositions.value
          .map((p) => '${p.index}:${p.itemLeadingEdge}:${p.itemTrailingEdge}')
          .join(', '),
    );
    rebuild(() {
      page = 0;
    });
    await tester.pumpAndSettle();
    expect(
      list.itemPositionsNotifier!.itemPositions.value.any(
        (p) => p.index == 4 && p.itemLeadingEdge < 1 && p.itemTrailingEdge > 0,
      ),
      isTrue,
      reason: list.itemPositionsNotifier!.itemPositions.value
          .map((p) => '${p.index}:${p.itemLeadingEdge}:${p.itemTrailingEdge}')
          .join(', '),
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('RTL reader reverses pages and does not swipe while zoomed', (
    tester,
  ) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPageView(
          pages: const [],
          controller: controller,
          direction: ReaderDirection.rtl,
          scaleType: ReaderScaleType.fitWidth,
          textColor: Colors.white,
          onPageChanged: (_) {},
        ),
      ),
    );
    final view = tester.widget<PageView>(find.byType(PageView));
    expect(view.reverse, isTrue);
    final zoom = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    zoom.transformationController!.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.pump();
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
  });
}
