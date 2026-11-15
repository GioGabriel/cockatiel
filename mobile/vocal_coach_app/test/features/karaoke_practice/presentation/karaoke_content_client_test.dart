import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vocal_coach_app/features/karaoke_practice/presentation/karaoke_singing_page.dart';

void main() {
  test(
      'selects the exact title and artist instead of the first lyricful result',
      () async {
    final contentClient = KaraokeContentClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'trackName': 'Glorify Your Name',
              'artistName': 'Another Artist',
              'syncedLyrics': '[00:01.00]wrong recording',
            },
            {
              'trackName': 'Glorify Your Name (Live)',
              'artistName': 'Hillsong Worship',
              'syncedLyrics': '[00:01.00]acceptable version',
            },
            {
              'trackName': 'Glorify Your Name',
              'artistName': 'Hillsong Worship',
              'syncedLyrics': '[00:01.00]exact recording',
            },
          ]),
          200,
        );
      }),
    );

    expect(
      await contentClient.fetchSyncedLyrics(
        title: 'Glorify Your Name',
        artist: 'Hillsong Worship',
      ),
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
              'artistName': 'Hillsong UNITED',
              'syncedLyrics': '[00:01.00]live lyrics',
            },
          ]),
          200,
        );
      }),
    );

    expect(
      await contentClient.fetchSyncedLyrics(
        title: 'All For Love',
        artist: 'Hillsong UNITED',
      ),
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
              'artistName': 'Hillsong UNITED',
              'syncedLyrics': '[00:01.00]wrong title',
            },
            {
              'trackName': 'Hosanna',
              'artistName': 'A Different Artist',
              'syncedLyrics': '[00:01.00]wrong artist',
            },
          ]),
          200,
        );
      }),
    );

    expect(
      await contentClient.fetchSyncedLyrics(
        title: 'Hosanna',
        artist: 'Hillsong UNITED',
      ),
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
              'artistName': 'Rusty Nelson',
              'syncedLyrics': '',
            },
          ]),
          200,
        );
      }),
    );

    expect(
      await contentClient.fetchSyncedLyrics(
        title: 'A Pure Heart',
        artist: 'Rusty Nelson',
      ),
      isNull,
    );
    contentClient.dispose();
  });
}
