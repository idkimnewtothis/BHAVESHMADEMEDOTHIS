import 'package:shonenx/shared/providers/storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PreferredScanlatorNotifier extends Notifier<String?> {
  final String mangaId;

  PreferredScanlatorNotifier(this.mangaId);

  @override
  String? build() {
    return ref.read(sharedPreferencesProvider).getString('scanlator:$mangaId');
  }

  void setPreferred(String? scanlator) {
    state = scanlator;
    final prefs = ref.read(sharedPreferencesProvider);
    if (scanlator == null) {
      prefs.remove('scanlator:$mangaId');
    } else {
      prefs.setString('scanlator:$mangaId', scanlator);
    }
  }
}

final preferredScanlatorProvider =
    NotifierProvider.family<PreferredScanlatorNotifier, String?, String>(
      PreferredScanlatorNotifier.new,
    );
