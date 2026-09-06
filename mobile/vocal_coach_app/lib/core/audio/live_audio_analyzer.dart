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
    this.zeroCrossingRate,
    this.spectralCentroidHz,
    this.spectralRolloffHz,
    this.crestFactorDb,
    this.clippingRatio,
    this.periodicity,
  });

  final int timestampMs;
  final double loudnessDb;
  final double? frequencyHz;
  final bool voiced;
  final double confidence;
  final double? zeroCrossingRate;
  final double? spectralCentroidHz;
  final double? spectralRolloffHz;
  final double? crestFactorDb;
  final double? clippingRatio;
  final double? periodicity;
}

/// Small, dependency-free acoustic descriptors for one microphone frame.
///
/// These are evidence fields, not clinical measurements. They are intentionally
/// kept separate from the pitch score until fixtures and human ratings calibrate
/// how (or whether) they should affect a score.
class AcousticFrameFeatures {
  const AcousticFrameFeatures({
    required this.zeroCrossingRate,
    required this.spectralCentroidHz,
    required this.spectralRolloffHz,
    required this.crestFactorDb,
    required this.clippingRatio,
  });

  final double zeroCrossingRate;
  final double spectralCentroidHz;
  final double spectralRolloffHz;
  final double crestFactorDb;
  final double clippingRatio;

  factory AcousticFrameFeatures.fromPcm16(
    List<int> frame, {
    required int sampleRate,
  }) {
    if (frame.isEmpty || sampleRate <= 0) {
      return const AcousticFrameFeatures(
        zeroCrossingRate: 0,
        spectralCentroidHz: 0,
        spectralRolloffHz: 0,
        crestFactorDb: 0,
        clippingRatio: 0,
      );
    }

    final samples = List<double>.generate(
      frame.length,
      (index) => frame[index] / 32768.0,
      growable: false,
    );
    var mean = 0.0;
    var peak = 0.0;
    var energy = 0.0;
    var clipped = 0;
    for (final sample in samples) {
      mean += sample;
      peak = max(peak, sample.abs());
      energy += sample * sample;
      if (sample.abs() >= 0.98) {
        clipped += 1;
      }
    }
    mean /= samples.length;
    final rms = sqrt(energy / samples.length);
    var crossings = 0;
    var previous = samples.first - mean;
    for (var index = 1; index < samples.length; index++) {
      final current = samples[index] - mean;
      if ((previous < 0 && current >= 0) || (previous >= 0 && current < 0)) {
        crossings += 1;
      }
      previous = current;
    }

    final spectrum = _powerSpectrum(samples, mean);
    final totalPower = spectrum.fold<double>(0, (sum, value) => sum + value);
    var centroid = 0.0;
    var rolloff = 0.0;
    final fftSize = max(2, (spectrum.length - 1) * 2);
    if (totalPower > 1e-12) {
      for (var bin = 1; bin < spectrum.length; bin++) {
        centroid += bin * sampleRate / fftSize * spectrum[bin];
      }
      centroid /= totalPower;
      final threshold = totalPower * 0.85;
      var cumulative = 0.0;
      for (var bin = 1; bin < spectrum.length; bin++) {
        cumulative += spectrum[bin];
        if (cumulative >= threshold) {
          rolloff = bin * sampleRate / fftSize;
          break;
        }
      }
    }

    return AcousticFrameFeatures(
      zeroCrossingRate: crossings / max(samples.length - 1, 1),
      spectralCentroidHz: centroid,
      spectralRolloffHz: rolloff,
      crestFactorDb: 20 * (log(max(peak, 1e-8) / max(rms, 1e-8)) / ln10),
      clippingRatio: clipped / samples.length,
    );
  }

  static List<double> _powerSpectrum(List<double> samples, double mean) {
    var size = 1;
    while (size * 2 <= samples.length) {
      size *= 2;
    }
    if (size < 2) {
      return const [0];
    }
    final real = List<double>.filled(size, 0);
    final imaginary = List<double>.filled(size, 0);
    for (var index = 0; index < size; index++) {
      final window = 0.5 * (1 - cos(2 * pi * index / (size - 1)));
      real[index] = (samples[index] - mean) * window;
    }

    var j = 0;
    for (var index = 1; index < size; index++) {
      var bit = size >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (index < j) {
        final realValue = real[index];
        real[index] = real[j];
        real[j] = realValue;
      }
    }

    for (var length = 2; length <= size; length <<= 1) {
      final angle = -2 * pi / length;
      final phaseReal = cos(angle);
      final phaseImaginary = sin(angle);
      for (var start = 0; start < size; start += length) {
        var twiddleReal = 1.0;
        var twiddleImaginary = 0.0;
        final half = length ~/ 2;
        for (var offset = 0; offset < half; offset++) {
          final even = start + offset;
          final odd = even + half;
          final productReal =
              twiddleReal * real[odd] - twiddleImaginary * imaginary[odd];
          final productImaginary =
              twiddleReal * imaginary[odd] + twiddleImaginary * real[odd];
          final evenReal = real[even];
          final evenImaginary = imaginary[even];
          real[even] = evenReal + productReal;
          imaginary[even] = evenImaginary + productImaginary;
          real[odd] = evenReal - productReal;
          imaginary[odd] = evenImaginary - productImaginary;
          final nextTwiddleReal =
              twiddleReal * phaseReal - twiddleImaginary * phaseImaginary;
          twiddleImaginary =
              twiddleReal * phaseImaginary + twiddleImaginary * phaseReal;
          twiddleReal = nextTwiddleReal;
        }
      }
    }
    return List<double>.generate(
      size ~/ 2 + 1,
      (index) =>
          real[index] * real[index] + imaginary[index] * imaginary[index],
      growable: false,
    );
  }
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
    final acoustic = AcousticFrameFeatures.fromPcm16(
      frame,
      sampleRate: sampleRate,
    );
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
        zeroCrossingRate: acoustic.zeroCrossingRate,
        spectralCentroidHz: acoustic.spectralCentroidHz,
        spectralRolloffHz: acoustic.spectralRolloffHz,
        crestFactorDb: acoustic.crestFactorDb,
        clippingRatio: acoustic.clippingRatio,
        periodicity: pitch?.confidence,
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
