import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release build number is newer than the previous Cockatiel APK', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      pubspec,
      contains(RegExp(r'^version: 5\.0\.0\+6\s*$', multiLine: true)),
    );
  });
}
