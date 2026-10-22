import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shonenx/source_engine/matchmaker/anime_matcher.dart';

void main() {
  final fixtures =
      jsonDecode(
            File('test/fixtures/anime-title-pairs.json').readAsStringSync(),
          )
          as List;
  for (final row in fixtures) {
    test('${row['target']} → ${row['source']}', () {
      final match = AnimeMatcher.compare([
        row['target'] as String,
      ], row['source'] as String);
      expect(match.autoAccept, row['accept']);
      expect(match.reason, isNotEmpty);
    });
  }
  test('Unicode width and accents fold without deleting native titles', () {
    expect(
      AnimeMatcher.normalize('Ｆｒｉｅｒｅｎ'),
      AnimeMatcher.normalize('Frieren'),
    );
    for (final title in ['進撃の巨人', '나 혼자만 레벨업', '斗罗大陆']) {
      expect(AnimeMatcher.normalize(title), isNotEmpty);
    }
  });
  test('known English and romaji aliases match', () {
    expect(
      AnimeMatcher.compare([
        'Shingeki no Kyojin',
        'Attack on Titan',
      ], 'Attack on Titan').autoAccept,
      isTrue,
    );
  });
  test('part split is never auto accepted', () {
    expect(
      AnimeMatcher.compare([
        'Attack on Titan Part 1',
      ], 'Attack on Titan Part 2').autoAccept,
      isFalse,
    );
  });
}
