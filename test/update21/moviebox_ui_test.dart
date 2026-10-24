import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shonenx/features/moviebox/moviebox_provider.dart';
import 'package:shonenx/features/moviebox/moviebox_screen.dart';
import 'package:shonenx/shared/providers/storage_provider.dart';
import 'package:shonenx/source_engine/moviebox/moviebox_source.dart';

void main() {
  testWidgets(
    'MovieBox ignores stale category responses, retries failures and loads next page',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'movieboxEndpoint': 'https://catalog.example/',
      });
      final prefs = await SharedPreferences.getInstance();
      final home = Completer<http.Response>();
      var animeRequests = 0;
      final pages = <String>[];
      final source = MovieBoxSource(
        'https://catalog.example',
        client: MockClient((r) async {
          if (r.url.path == '/home') return home.future;
          expect(r.url.path, '/anime');
          pages.add(r.url.queryParameters['page']!);
          if (++animeRequests == 1) return http.Response('unavailable', 503);
          return http.Response(
            jsonEncode({
              'code': 0,
              'data': {
                'items': [
                  {
                    'subjectId': r.url.queryParameters['page'],
                    'title': 'Anime page ${r.url.queryParameters['page']}',
                  },
                ],
              },
            }),
            200,
          );
        }),
      );
      addTearDown(source.close);
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const MovieBoxScreen())],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            movieBoxSourceProvider.overrideWithValue(source),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Anime'));
      await tester.pumpAndSettle();
      expect(find.textContaining('HTTP 503'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Anime page 1'), findsOneWidget);
      home.complete(
        http.Response(
          '{"code":0,"data":{"items":[{"subjectId":"old","title":"Old home result"}]}}',
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Old home result'), findsNothing);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Anime page 2'), findsOneWidget);
      expect(pages, ['1', '1', '2']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'MovieBox connection validates URL and dialog can be dismissed safely',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const MovieBoxScreen())],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('MovieBox UI'), findsOneWidget);
      await tester.tap(find.text('Connect server'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'http://public.example',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('HTTPS'), findsWidgets);
      expect(prefs.getString('movieboxEndpoint'), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Connect server'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
