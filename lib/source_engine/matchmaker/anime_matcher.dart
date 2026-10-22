import 'dart:math';
import 'package:unorm_dart/unorm_dart.dart' as unicode;

class AnimeMatch {
  final String title;
  final double confidence;
  final String reason;
  final bool seasonCompatible;
  const AnimeMatch(
    this.title,
    this.confidence,
    this.reason,
    this.seasonCompatible,
  );
  bool get autoAccept => seasonCompatible && confidence >= .96;
}

class AnimeMatcher {
  static String fold(String title) => unicode
      .nfkd(title)
      .toLowerCase()
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  static int season(String title) {
    final s = fold(title);
    final match = RegExp(
      r'(?:season\s*(\d+)|(\d+)(?:st|nd|rd|th)\s+season)',
    ).firstMatch(s);
    if (match != null) return int.parse(match.group(1) ?? match.group(2)!);
    final roman = RegExp(
      r'\s+(i{1,3}|iv|v|vi{1,3}|ix|x)$',
    ).firstMatch(s)?.group(1);
    return const {
          'i': 1,
          'ii': 2,
          'iii': 3,
          'iv': 4,
          'v': 5,
          'vi': 6,
          'vii': 7,
          'viii': 8,
          'ix': 9,
          'x': 10,
        }[roman] ??
        1;
  }

  static int part(String title) =>
      int.tryParse(
        RegExp(r'(?:part|cour)\s*(\d+)').firstMatch(fold(title))?.group(1) ??
            '',
      ) ??
      1;
  static String normalize(String title) => fold(title)
      .replaceAll(RegExp(r'\((?:tv|\d{4})\)'), ' ')
      .replaceAll(
        RegExp(
          r'(?:season\s*\d+|\d+(?:st|nd|rd|th)\s+season|(?:part|cour)\s*\d+)',
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+(?:i{1,3}|iv|v|vi{1,3}|ix|x)$'), ' ')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
  static double similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final x = a.runes.toList(), y = b.runes.toList();
    var row = List.generate(y.length + 1, (i) => i);
    for (var i = 0; i < x.length; i++) {
      final next = <int>[i + 1];
      for (var j = 0; j < y.length; j++) {
        next.add(
          min(
            min(next[j] + 1, row[j + 1] + 1),
            row[j] + (x[i] == y[j] ? 0 : 1),
          ),
        );
      }
      row = next;
    }
    final edit = 1 - row.last / max(x.length, y.length);
    final left = a.split(' ').toSet(), right = b.split(' ').toSet();
    final tokens =
        2 * left.intersection(right).length / (left.length + right.length);
    return max(edit, tokens);
  }

  static AnimeMatch compare(
    List<String> aliases,
    String sourceTitle, {
    int? year,
    int? sourceYear,
    String? format,
    String? sourceFormat,
    int? episodes,
    int? sourceEpisodes,
  }) {
    var best = 0.0;
    String? alias;
    var compatible = false;
    for (final title in aliases.where((s) => s.trim().isNotEmpty)) {
      final same =
          season(title) == season(sourceTitle) &&
          part(title) == part(sourceTitle);
      final score = similarity(normalize(title), normalize(sourceTitle));
      final adjusted = same ? score : min(score, .49);
      if (adjusted > best) {
        best = adjusted;
        alias = title;
        compatible = same;
      }
    }
    final reasons = <String>[
      'Title similarity to ${alias ?? "no known alias"}',
      compatible ? 'Same season and part' : 'Season or part differs',
    ];
    if (year != null && sourceYear != null) {
      best += year == sourceYear ? 0.02 : -0.15;
      reasons.add(year == sourceYear ? 'Year agrees' : 'Year differs');
    }
    if (format != null && sourceFormat != null) {
      best += format.toLowerCase() == sourceFormat.toLowerCase() ? 0.02 : -0.15;
    }
    if (episodes != null && sourceEpisodes != null) {
      best += episodes == sourceEpisodes ? 0.01 : -0.03;
    }
    return AnimeMatch(
      sourceTitle,
      best.clamp(0, compatible ? 1 : .49),
      reasons.join('; '),
      compatible,
    );
  }

  static List<AnimeMatch> rank(
    List<String> aliases,
    Iterable<String> candidates, {
    int k = 5,
  }) {
    final results = candidates.map((s) => compare(aliases, s)).toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    return results.take(k).toList();
  }
}
