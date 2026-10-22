import 'package:flutter_test/flutter_test.dart';
import 'package:anymex_extension_runtime_bridge/Models/DMedia.dart';

void main() {
  test('native detail transport retains URL, status and episode fields', () {
    final title = DMedia.fromJson({
      'title': 'Test title',
      'url': '/anime/season-2',
      'thumbnail_url': 'https://example.test/cover.jpg',
      'description': 'Description',
      'genre': ['Drama'],
      'status': 'Ongoing',
      'episodes': [
        {
          'url': '/episode/12.5',
          'name': 'Special',
          'episodeNumber': 12.5,
          'dateUpload': 1700000000000,
          'thumbnail': 'https://example.test/episode.jpg',
        },
      ],
    });
    expect(title.url, '/anime/season-2');
    expect(title.status, 'Ongoing');
    expect(title.cover, endsWith('cover.jpg'));
    expect(title.genre, ['Drama']);
    final episode = title.episodes!.single;
    expect(episode.episodeNumber, '12.5');
    expect(episode.dateUpload, '1700000000000');
    expect(episode.thumbnail, endsWith('episode.jpg'));
    expect(DMedia.fromJson(title.toJson()).status, 'Ongoing');
  });
}
