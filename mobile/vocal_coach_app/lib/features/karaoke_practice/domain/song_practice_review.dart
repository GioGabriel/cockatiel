import '../../../shared/models/session_models.dart';

/// Keep a saved take on a failed finalize request. Duplicate taps share the
/// same operation, and a retry resumes at the unfinished request.
class SongPracticeReviewController {
  bool _saved = false;
  FinalizeResponse? _result;
  Future<FinalizeResponse>? _pending;
  bool get hasSavedAttempt => _saved;

  Future<FinalizeResponse> submit(
      {required Future<void> Function() saveAttempt,
      required Future<FinalizeResponse> Function() finalize}) {
    if (_result != null) return Future.value(_result);
    return _pending ??=
        _submit(saveAttempt, finalize).whenComplete(() => _pending = null);
  }

  Future<FinalizeResponse> _submit(Future<void> Function() save,
      Future<FinalizeResponse> Function() finalize) async {
    if (!_saved) {
      await save();
      _saved = true;
    }
    return _result = await finalize();
  }
}
