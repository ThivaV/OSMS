// The briefing's audio in the real macOS app: AVPlayer in the app's sandbox, over plain
// http to localhost (App Transport Security's local-networking exception), with byte
// ranges for seeking, the way the API serves a briefing. Needs nothing else running:
//
//   cd frontend && flutter test integration_test/briefing_audio_test.dart -d macos

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:osms/core/audio/briefing_playback.dart';

/// A 16 kHz mono 16-bit WAV of a quiet tone, like the briefing's own audio.
Uint8List toneWav(Duration length) {
  const rate = 16000;
  final samples = rate * length.inMilliseconds ~/ 1000;
  final data = ByteData(44 + samples * 2);
  void ascii(int at, String s) => s.codeUnits.asMap().forEach((i, c) => data.setUint8(at + i, c));
  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    data.setInt16(44 + i * 2, (sin(2 * pi * 440 * i / rate) * 800).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Serves [wav] like the API's FileResponse: whole, or the byte range asked for.
Future<HttpServer> serve(Uint8List wav, List<String> log) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final range = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(request.headers.value('range') ?? '');
    final response = request.response..headers.contentType = ContentType('audio', 'wav');
    response.headers.set('accept-ranges', 'bytes');
    if (range == null) {
      log.add('200');
      response.contentLength = wav.length;
      response.add(wav);
    } else {
      final start = int.parse(range.group(1)!);
      final end = range.group(2)!.isEmpty ? wav.length - 1 : min(int.parse(range.group(2)!), wav.length - 1);
      log.add('206 $start-$end');
      response
        ..statusCode = HttpStatus.partialContent
        ..headers.set('content-range', 'bytes $start-$end/${wav.length}')
        ..contentLength = end - start + 1
        ..add(wav.sublist(start, end + 1));
    }
    await response.close();
  });
  return server;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a briefing plays, seeks and pauses in the real app', (tester) async {
    final requests = <String>[];
    final server = await serve(toneWav(const Duration(seconds: 6)), requests);
    final playback = JustAudioPlayback('http://localhost:${server.port}/briefings/1/audio?expires=1&signature=s');
    addTearDown(() async {
      playback.dispose();
      await server.close(force: true);
    });

    Future<void> until(bool Function(PlaybackState) ok, String what) async {
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (!ok(playback.state.value)) {
        if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what: ${playback.state.value.position}');
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      }
    }

    await tester.runAsync(playback.play);
    await until((s) => s.playing && s.position > const Duration(milliseconds: 500), 'playback to start');
    expect(playback.state.value.failed, isFalse);

    await tester.runAsync(() => playback.seek(const Duration(seconds: 4)));
    await until((s) => s.position >= const Duration(seconds: 4), 'the seek');

    await tester.runAsync(playback.pause);
    await until((s) => !s.playing, 'the pause');
    expect(requests, isNotEmpty);
  });
}
