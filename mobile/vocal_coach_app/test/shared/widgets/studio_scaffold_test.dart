import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/widgets/studio_scaffold.dart';

void main() {
  testWidgets(
      'desktop reading grid preserves space for a compact bottom action',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: StudioScaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: ListView(children: const [Text('Your exercise')]),
      bottomNavigationBar: SafeArea(
          child: FilledButton(onPressed: () {}, child: const Text('Start'))),
    )));
    expect(tester.getSize(find.byType(ListView)).height, greaterThan(700));
    expect(
        tester.getSize(find.byType(ListView)).width, lessThanOrEqualTo(1040));
    expect(tester.getSize(find.byType(FilledButton)).width,
        lessThanOrEqualTo(680));
    expect(tester.takeException(), isNull);
  });
}
