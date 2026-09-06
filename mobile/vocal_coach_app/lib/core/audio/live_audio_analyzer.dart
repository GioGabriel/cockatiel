import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'pitch/yin_pitch_estimator.dart';

class LiveAudioFrame {
  LiveAudioFrame({
    required this.timestampMs,
    required this.loudnessDb,
    required this.frequencyHz,
    required this.voiced,
    required this.confidence,
  });

  final int timestampMs;
  final double loudnessDb;
  final double? frequencyHz;
  final bool voiced;
  final double confidence;
}

class LiveAudioAnalyzer {
  LiveAudioAnalyzer({
    this.sampleRate = 16000,
    this.frameSize = 2048,
    this.hopSize = 512,
    this.minFrequencyHz = 80,
    this.maxFrequencyHz = 520,
  });

  final int sampleRate;
  final int frameSize;
  final int hopSize;
  final int minFrequencyHz;
  final int maxFrequencyHz;

  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<LiveAudioFrame> _framesController =
      StreamController<LiveAudioFrame>.broadcast();
  late final YinPitchEstimator _pitchEstimator = YinPitchEstimator(
    sampleRate: sampleRate,
    minFrequencyHz: minFrequencyHz,
    maxFrequencyHz: maxFrequencyHz,
  );

  StreamSubscription<Uint8List>? _streamSubscription;
  List<int> _pendingSamples = <int>[];
  bool _started = false;

  Stream<LiveAudioFrame> get frames => _framesController.stream;

  Future<void> start() async {
    if (_started) {
      return;
    }
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw StateError('Microphone permission was not granted.');
    }

    final pcmStream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );

    _started = true;
    _pendingSamples = <int>[];
    _streamSubscription = pcmStream.listen(
      _onChunk,
      onError: (Object error, StackTrace trace) {
        _framesController.addError(error, trace);
      },
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _pendingSamples = <int>[];
    if (_started) {
      await _recorder.stop();
    }
    _started = false;
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
    await _framesController.close();
  }

  void _onChunk(Uint8List chunk) {
    final byteData = ByteData.sublistView(chunk);
    for (var offset = 0; offset + 1 < chunk.length; offset += 2) {
      _pendingSamples.add(byteData.getInt16(offset, Endian.little));
    }

    while (_pendingSamples.length >= frameSize) {
      final frame = _pendingSamples.sublist(0, frameSize);
      _pendingSamples = _pendingSamples.sublist(hopSize);
      _emitFrame(frame);
    }
  }

  void _emitFrame(List<int> frame) {
    final loudnessDb = _computeLoudnessDb(frame);
    final pitch = _pitchEstimator.estimate(frame);
    final frequencyHz =
        (pitch != null && loudnessDb > -55) ? pitch.frequencyHz : null;
    final isVoiced = frequencyHz != null;

    _framesController.add(
      LiveAudioFrame(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        loudnessDb: loudnessDb,
        frequencyHz: frequencyHz,
        voiced: isVoiced,
        confidence: pitch?.confidence ?? 0,
      ),
    );
  }

  double _computeLoudnessDb(List<int> frame) {
    var energy = 0.0;
    for (final sample in frame) {
      final normalized = sample / 32768.0;
      energy += normalized * normalized;
    }
    final rms = sqrt(energy / frame.length).clamp(1e-8, 1.0);
    return 20 * (log(rms) / ln10);
  }
}
