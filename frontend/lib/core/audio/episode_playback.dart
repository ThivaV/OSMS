import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'briefing_playback.dart';

/// Episode audio. There is deliberately one audio engine in the app:
/// `BriefingPlayback` is pure URL audio (no chapters live in it), so episodes
/// play through the same player, fakes and all. The alias keeps call sites
/// honest about what is playing, and HomeScreen keeps the rule of one audio
/// at a time: starting an episode pauses the briefing and vice versa.
typedef EpisodePlayback = BriefingPlayback;

/// How the app makes a player for an episode's enclosure; tests swap in a fake.
final episodePlaybackProvider = Provider<EpisodePlayback Function(String url)>((ref) => JustAudioPlayback.new);
