import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release build number upgrades the supplied Cockatiel V10 APK', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version =
        RegExp(r'^version:\s*\d+\.\d+\.\d+\+(\d+)\s*$', multiLine: true)
            .firstMatch(pubspec);
    expect(version, isNotNull,
        reason: 'Android releases need an explicit build number.');
    expect(int.parse(version!.group(1)!), greaterThan(6),
        reason: 'The supplied Cockatiel V10 Updated.apk has versionCode 6.');
  });
}
