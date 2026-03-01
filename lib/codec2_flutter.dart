import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

// ── Codec2 mode constants (match codec2.h) ───────────────────────────────────

/// Codec2 operating modes.
/// Numeric values match the C constants in codec2.h.
enum Codec2Mode {
  /// 3200 bps.
  mode3200(0),

  /// 2400 bps — higher quality, ~300 bytes/sec output at 8kHz.
  mode2400(1),

  /// 1600 bps.
  mode1600(2),

  /// 1400 bps.
  mode1400(3),

  /// 1300 bps — good quality for LoRa, ~175 bytes/sec at 8kHz (25 fps × 7 B).
  mode1300(4),

  /// 1200 bps — ~150 bytes/sec at 8kHz (25 fps × 6 B).
  mode1200(5),

  /// 700C bps — minimum bandwidth for very narrow LoRa / ham radio channels.
  /// ~100 bytes/sec output at 8kHz.
  mode700c(8);

  const Codec2Mode(this.c2ModeId);

  /// The integer passed to codec2_create() in C.
  final int c2ModeId;

  /// Audio frames per second for this mode (all modes use 8000 Hz sample rate).
  int get framesPerSecond =>
      (this == mode3200 || this == mode2400) ? 50 : 25;

  /// Samples per frame (8000 Hz / framesPerSecond).
  int get samplesPerFrame => 8000 ~/ framesPerSecond;

  /// Payload bytes per second (bitsPerFrame × framesPerSecond / 8).
  /// Used to calculate packet duration for the 172-byte BLE frame limit.
  int get bytesPerSecond {
    switch (this) {
      case mode3200:
        return 400; // 8 B × 50 fps
      case mode700c:
        return 100; // ceil(28/8)=4 B × 25 fps
      case mode1200:
        return 150; // 6 B × 25 fps
      case mode1300:
        return 175; // ceil(52/8)=7 B × 25 fps
      case mode1400:
        return 175; // 7 B × 25 fps
      case mode1600:
        return 200; // 8 B × 25 fps
      case mode2400:
        return 300; // 6 B × 50 fps
    }
  }

  /// Maximum Codec2 bytes per radio packet.
  /// MAX_FRAME_SIZE=172, minus 4 bytes pushRawData header, minus 8 bytes voice header.
  static const int _maxBytesPerPacket = 160;

  /// Optimal packet duration in milliseconds so the encoded data fits in one BLE frame.
  /// Calculated as: floor(maxBytes / bytesPerFrame) frames × frame duration.
  int get packetDurationMs {
    final bytesPerFrame = bytesPerSecond / framesPerSecond; // e.g. 6 B for 1200
    final framesPerPacket = (_maxBytesPerPacket / bytesPerFrame).floor();
    return (framesPerPacket * 1000 ~/ framesPerSecond);
  }
}

// ── Native type definitions ──────────────────────────────────────────────────

typedef _Codec2CreateFn  = Pointer<Void> Function(Int32 mode);
typedef _Codec2CreateDart = Pointer<Void> Function(int mode);

typedef _Codec2DestroyFn  = Void Function(Pointer<Void> c2);
typedef _Codec2DestroyDart = void Function(Pointer<Void> c2);

typedef _Codec2EncodeFn  = Void Function(Pointer<Void> c2, Pointer<Uint8> bits, Pointer<Int16> speech);
typedef _Codec2EncodeDart = void Function(Pointer<Void> c2, Pointer<Uint8> bits, Pointer<Int16> speech);

typedef _Codec2DecodeFn  = Void Function(Pointer<Void> c2, Pointer<Int16> speech, Pointer<Uint8> bits);
typedef _Codec2DecodeDart = void Function(Pointer<Void> c2, Pointer<Int16> speech, Pointer<Uint8> bits);

typedef _Codec2IntFn   = Int32 Function(Pointer<Void> c2);
typedef _Codec2IntDart  = int    Function(Pointer<Void> c2);

// ── Library loader ────────────────────────────────────────────────────────────

DynamicLibrary _loadLib() {
  if (Platform.isAndroid) return DynamicLibrary.open('libcodec2_flutter.so');
  // iOS & macOS link statically via CocoaPods — all symbols live in the process.
  return DynamicLibrary.process();
}

// ── Codec2 instance ───────────────────────────────────────────────────────────

/// A single Codec2 encoder/decoder instance.
///
/// Create with [Codec2.create], call [encode]/[decode], then [destroy].
///
/// **Thread safety**: each instance must be used from a single thread/isolate.
/// Use [Codec2.encodeInIsolate] / [Codec2.decodeInIsolate] for off-UI encoding.
class Codec2 {
  Codec2._(this._c2, this._lib, this.mode);

  final Pointer<Void> _c2;
  final DynamicLibrary _lib;
  final Codec2Mode mode;

  late final _Codec2EncodeDart _encode =
      _lib.lookupFunction<_Codec2EncodeFn, _Codec2EncodeDart>('codec2_encode');
  late final _Codec2DecodeDart _decode =
      _lib.lookupFunction<_Codec2DecodeFn, _Codec2DecodeDart>('codec2_decode');
  late final _Codec2IntDart _samplesPerFrame =
      _lib.lookupFunction<_Codec2IntFn, _Codec2IntDart>('codec2_samples_per_frame');
  late final _Codec2IntDart _bitsPerFrame =
      _lib.lookupFunction<_Codec2IntFn, _Codec2IntDart>('codec2_bits_per_frame');

  /// Samples per frame for this codec mode.
  int get samplesPerFrame => _samplesPerFrame(_c2);

  /// Bits per frame for this codec mode.
  int get bitsPerFrame => _bitsPerFrame(_c2);

  /// Bytes per frame (rounded up from bitsPerFrame).
  int get bytesPerFrame => (bitsPerFrame + 7) ~/ 8;

  /// Create a new Codec2 instance for [mode].
  static Codec2 create(Codec2Mode mode) {
    final lib = _loadLib();
    final createFn =
        lib.lookupFunction<_Codec2CreateFn, _Codec2CreateDart>('codec2_create');
    final c2 = createFn(mode.c2ModeId);
    if (c2 == nullptr) throw StateError('codec2_create(${mode.c2ModeId}) returned null');
    return Codec2._(c2, lib, mode);
  }

  /// Encode [pcmSamples] (Int16, 8000 Hz mono) to Codec2 bytes.
  ///
  /// [pcmSamples.length] must be a multiple of [samplesPerFrame].
  Uint8List encode(Int16List pcmSamples) {
    final spf = samplesPerFrame;
    final bpf = bytesPerFrame;
    final nFrames = pcmSamples.length ~/ spf;
    if (nFrames == 0) return Uint8List(0);

    final outputBytes = nFrames * bpf;
    final speechPtr = calloc<Int16>(spf);
    final bitsPtr   = calloc<Uint8>(bpf);
    final result    = Uint8List(outputBytes);

    try {
      for (var f = 0; f < nFrames; f++) {
        // Copy one frame of PCM into native memory
        for (var s = 0; s < spf; s++) {
          speechPtr[s] = pcmSamples[f * spf + s];
        }
        _encode(_c2, bitsPtr, speechPtr);
        // Copy encoded bits into result
        final offset = f * bpf;
        for (var b = 0; b < bpf; b++) {
          result[offset + b] = bitsPtr[b];
        }
      }
    } finally {
      calloc.free(speechPtr);
      calloc.free(bitsPtr);
    }
    return result;
  }

  /// Decode Codec2 [encoded] bytes to Int16 PCM samples (8000 Hz mono).
  ///
  /// [encoded.length] must be a multiple of [bytesPerFrame].
  Int16List decode(Uint8List encoded) {
    final spf = samplesPerFrame;
    final bpf = bytesPerFrame;
    final nFrames = encoded.length ~/ bpf;
    if (nFrames == 0) return Int16List(0);

    final totalSamples = nFrames * spf;
    final speechPtr = calloc<Int16>(spf);
    final bitsPtr   = calloc<Uint8>(bpf);
    final result    = Int16List(totalSamples);

    try {
      for (var f = 0; f < nFrames; f++) {
        final offset = f * bpf;
        for (var b = 0; b < bpf; b++) {
          bitsPtr[b] = encoded[offset + b];
        }
        _decode(_c2, speechPtr, bitsPtr);
        final sOffset = f * spf;
        for (var s = 0; s < spf; s++) {
          result[sOffset + s] = speechPtr[s];
        }
      }
    } finally {
      calloc.free(speechPtr);
      calloc.free(bitsPtr);
    }
    return result;
  }

  /// Free the native Codec2 instance. Must be called when done.
  void destroy() {
    final destroyFn =
        _lib.lookupFunction<_Codec2DestroyFn, _Codec2DestroyDart>('codec2_destroy');
    destroyFn(_c2);
  }

  // ── Isolate helpers ──────────────────────────────────────────────────────

  /// Encode [pcm] in a separate [Isolate] (avoids blocking the UI thread).
  static Future<Uint8List> encodeInIsolate(Int16List pcm, Codec2Mode mode) {
    return Isolate.run(() {
      final c2 = Codec2.create(mode);
      try {
        return c2.encode(pcm);
      } finally {
        c2.destroy();
      }
    });
  }

  /// Decode [encoded] bytes in a separate [Isolate].
  static Future<Int16List> decodeInIsolate(Uint8List encoded, Codec2Mode mode) {
    return Isolate.run(() {
      final c2 = Codec2.create(mode);
      try {
        return c2.decode(encoded);
      } finally {
        c2.destroy();
      }
    });
  }
}
