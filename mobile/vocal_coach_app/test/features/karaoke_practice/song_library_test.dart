import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/features/karaoke_practice/domain/song_library.dart';
import 'package:vocal_coach_app/shared/models/karaoke_models.dart';
import 'package:vocal_coach_app/shared/models/training_models.dart';

void main() {
  test('an unresponsive progress request cannot stall the song library',
      () async {
    const catalog = KaraokeCatalog(
        moduleId: 'songs', title: 'Songs', description: '', categories: []);
    final result = await loadSongLibrary(
        fetchCatalog: () async => catalog,
        fetchProgress: () => Completer<TrainingProgress>().future,
        progressTimeout: Duration.zero);
    expect(result.catalog, same(catalog));
    expect(result.progress, isNull);
  });
  test('a progress outage does not hide an available song catalog', () async {
    const catalog = KaraokeCatalog(
        moduleId: 'songs', title: 'Songs', description: '', categories: []);
    final result = await loadSongLibrary(
      fetchCatalog: () async => catalog,
      fetchProgress: () async => throw StateError('progress unavailable'),
    );
    expect(result.catalog, same(catalog));
    expect(result.progress, isNull);
  });
  test(
      'a catalog outage remains actionable instead of presenting an empty library',
      () async {
    await expectLater(
        loadSongLibrary(
          fetchCatalog: () async => throw StateError('catalog unavailable'),
          fetchProgress: () async =>
              TrainingProgress(userId: 'user', generatedAt: 0, items: []),
        ),
        throwsStateError);
  });
}
