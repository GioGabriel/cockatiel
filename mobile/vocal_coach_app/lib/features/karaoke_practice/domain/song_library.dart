import '../../../shared/models/karaoke_models.dart';
import '../../../shared/models/training_models.dart';

class SongLibrarySnapshot {
  const SongLibrarySnapshot(this.catalog, this.progress);
  final KaraokeCatalog catalog;
  final TrainingProgress? progress;
}

Future<SongLibrarySnapshot> loadSongLibrary({
  required Future<KaraokeCatalog> Function() fetchCatalog,
  required Future<TrainingProgress> Function() fetchProgress,
  Duration progressTimeout = const Duration(seconds: 5),
}) async {
  // Attach the recovery handler immediately so an optional progress failure
  // cannot become an unhandled error while the catalog is still loading.
  final progress = fetchProgress()
      .timeout(progressTimeout)
      .then<TrainingProgress?>((value) => value, onError: (Object _) => null);
  final catalog = await fetchCatalog().timeout(const Duration(seconds: 15));
  return SongLibrarySnapshot(catalog, await progress);
}
