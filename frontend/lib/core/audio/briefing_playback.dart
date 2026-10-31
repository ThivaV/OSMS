import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// What the briefing players show: one recording, shared by the floating bar and the
/// full player.
@immutable
class PlaybackState {
  const PlaybackState({this.playing = false, this.position = Duration.zero, this.speed = 1.0, this.failed = false});

  final bool playing;
  final Duration position;
  final double speed;

  /// The audio couldn't be loaded (offline, or its link expired).
  final bool failed;

  PlaybackState copyWith({bool? playing, Duration? position, double? speed, bool? failed}) => PlaybackState(
    playing: playing ?? this.playing,
    position: position ?? this.position,
    speed: speed ?? this.speed,
    failed: failed ?? this.failed,
  );
}

abstract class BriefingPlayback {
  ValueListenable<PlaybackState> get state;
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  void dispose();
}

/// The briefing's audio through just_audio, loaded on the first play.
class JustAudioPlayback implements BriefingPlayback {
  JustAudioPlayback(this.url);

  final String url;
  final _player = AudioPlayer();
  final _state = ValueNotifier(const PlaybackState());
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<bool>? _loading;

  @override
  ValueListenable<PlaybackState> get state => _state;

  Future<bool> _load() => _loading ??= () async {
    _subscriptions
      ..add(_player.positionStream.listen((p) => _state.value = _state.value.copyWith(position: p)))
      ..add(
        _player.playerStateStream.listen(
          (s) => _state.value = _state.value.copyWith(
            playing: s.playing && s.processingState != ProcessingState.completed,
          ),
        ),
      );
    try {
      await _player.setUrl(url);
      return true;
    } catch (_) {
      _state.value = _state.value.copyWith(failed: true, playing: false);
      return false;
    }
  }();

  @override
  Future<void> play() async {
    if (!await _load()) return;
    if (_player.processingState == ProcessingState.completed) await _player.seek(Duration.zero);
    unawaited(_player.play()); // Completes only when playback stops.
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) async {
    if (!await _load()) return;
    _state.value = _state.value.copyWith(position: position);
    await _player.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    _state.value = _state.value.copyWith(speed: speed);
    await _player.setSpeed(speed);
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_player.dispose());
    _state.dispose();
  }
}

/// How the app makes a player for a briefing's audio; tests swap in a fake.
final briefingPlaybackProvider = Provider<BriefingPlayback Function(String url)>((ref) => JustAudioPlayback.new);
