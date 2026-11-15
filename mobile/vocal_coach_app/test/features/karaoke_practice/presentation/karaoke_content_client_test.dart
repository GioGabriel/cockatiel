import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vocal_coach_app/features/karaoke_practice/presentation/karaoke_singing_page.dart';

void main() {
  test('retains untimed lyrics for the matching recording', () async {
    final client = KaraokeContentClient(httpClient: MockClient((_) async {
      return http.Response(
          jsonEncode([
            {
              'trackName': 'A Place at Your Altar',
              'artistName': 'Randy Rothwell',
              'duration': 224,
              'syncedLyrics': null,
              'plainLyrics': 'First line\nSecond line'
            },
          ]),
          200);
    }));
    final result = await client.fetchLyrics(
        title: 'A Place at Your Altar',
        artist: 'Randy Rothwell',
        durationSec: 224);
    expect(result?.syncedLyrics, isNull);
    expect(result?.plainLyrics, 'First line\nSecond line');
    client.dispose();
  });

  test(
      'selects the exact title and artist instead of the first lyricful result',
      () async {
    final contentClient = KaraokeContentClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'trackName': 'Glorify Your Name',
              'duration': 300,
              'artistName': 'Another Artist',
              'syncedLyrics': '[00:01.00]wrong recording',
            },
            {
              'trackName': 'Glorify Your Name (Live)',
              'duration': 300,
              'artistName': 'Hillsong Worship',
              'syncedLyrics': '[00:01.00]acceptable version',
            },
            {
              'trackName': 'Glorify Your Name',
              'duration': 300,
              'artistName': 'Hillsong Worship',
              'syncedLyrics': '[00:01.00]exact recording',
            },
          ]),
          200,
        );
      }),
    );

    expect(
      (await contentClient.fetchLyrics(
        title: 'Glorify Your Name',
        durationSec: 300,
        artist: 'Hillsong Worship',
      ))
          ?.syncedLyrics,
      '[00:01.00]exact recording',
    );
    contentClient.dispose();
  });

  test('allows a clearly labelled live variant when no exact title exists',
      () async {
    final contentClient = KaraokeContentClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'trackName': 'All For Love (Live)',
              'duration': 300,
              'artistName': 'Hillsong UNITED',
              'syncedLyrics': '[00:01.00]live lyrics',
            },
          ]),
          200,
        );
      }),
    );

    expect(
      (await contentClient.fetchLyrics(
        title: 'All For Love',
        durationSec: 300,
        artist: 'Hillsong UNITED',
      ))
          ?.syncedLyrics,
      '[00:01.00]live lyrics',
    );
    contentClient.dispose();
  });

  test('does not use lyrics for a different title or artist', () async {
    final contentClient = KaraokeContentClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'trackName': 'A Different Song',
              'duration': 300,
              'artistName': 'Hillsong UNITED',
              'syncedLyrics': '[00:01.00]wrong title',
            },
            {
              'trackName': 'Hosanna',
              'duration': 300,
              'artistName': 'A Different Artist',
              'syncedLyrics': '[00:01.00]wrong artist',
            },
          ]),
          200,
        );
      }),
    );

    expect(
      (await contentClient.fetchLyrics(
        title: 'Hosanna',
        durationSec: 300,
        artist: 'Hillsong UNITED',
      ))
          ?.syncedLyrics,
      isNull,
    );
    contentClient.dispose();
  });

  test('ignores results without synchronized lyrics', () async {
    final contentClient = KaraokeContentClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'trackName': 'A Pure Heart',
              'duration': 300,
              'artistName': 'Rusty Nelson',
              'syncedLyrics': '',
            },
          ]),
          200,
        );
      }),
    );

    expect(
      (await contentClient.fetchLyrics(
        title: 'A Pure Heart',
        durationSec: 300,
        artist: 'Rusty Nelson',
      ))
          ?.syncedLyrics,
      isNull,
    );
    contentClient.dispose();
  });

  test('rejects a shorter edit and selects the closest recording duration',
      () async {
    final client = KaraokeContentClient(httpClient: MockClient((_) async {
      return http.Response(
          jsonEncode([
            {
              'trackName': 'A Man After Your Own Heart',
              'artistName': 'Gary Chapman',
              'duration': 275,
              'syncedLyrics': 'short edit'
            },
            {
              'trackName': 'A Man After Your Own Heart',
              'artistName': 'Gary Chapman',
              'duration': 296,
              'syncedLyrics': 'near match'
            },
            {
              'trackName': 'A Man After Your Own Heart',
              'artistName': 'Gary Chapman',
              'duration': 294,
              'syncedLyrics': 'album recording'
            },
          ]),
          200);
    }));
    expect(
        (await client.fetchLyrics(
                title: 'A Man After Your Own Heart',
                artist: 'Gary Chapman',
                durationSec: 294))
            ?.syncedLyrics,
        'album recording');
    client.dispose();
  });

  test('does not guess when recording durations are missing or invalid',
      () async {
    for (final duration in [null, '294', -1, 0, 297]) {
      final client = KaraokeContentClient(httpClient: MockClient((_) async {
        return http.Response(
            jsonEncode([
              {
                'trackName': 'A Man After Your Own Heart',
                'artistName': 'Gary Chapman',
                'duration': duration,
                'syncedLyrics': 'unverified timing'
              },
            ]),
            200);
      }));
      expect(
          (await client.fetchLyrics(
                  title: 'A Man After Your Own Heart',
                  artist: 'Gary Chapman',
                  durationSec: 294))
              ?.syncedLyrics,
          isNull,
          reason: 'duration=$duration');
      client.dispose();
    }
  });
}
