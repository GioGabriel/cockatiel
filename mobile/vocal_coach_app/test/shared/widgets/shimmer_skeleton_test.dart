import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vocal_coach_app/shared/widgets/shimmer_skeleton.dart';

void main() {
  final theme = ThemeData.light();

  Widget buildApp(Widget child) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(body: child),
    );
  }

  group('ShimmerSkeleton', () {
    testWidgets('renders Shimmer widget in the tree', (tester) async {
      await tester.pumpWidget(
        buildApp(
          ShimmerSkeleton(
            child: SizedBox(height: 100, width: double.infinity),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('renders child widget inside shimmer', (tester) async {
      await tester.pumpWidget(
        buildApp(
          ShimmerSkeleton(
            child: SizedBox(
              key: const Key('skeleton-child'),
              height: 80,
              width: double.infinity,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('skeleton-child')), findsOneWidget);
    });

    testWidgets('shimmer animation is running after pump', (tester) async {
      await tester.pumpWidget(
        buildApp(
          ShimmerSkeleton(
            child: SizedBox(height: 100, width: double.infinity),
          ),
        ),
      );

      // Pump a frame to advance the animation
      await tester.pump(const Duration(milliseconds: 600));

      // Shimmer should still be in the tree and animating
      expect(find.byType(Shimmer), findsOneWidget);
    });
  });

  group('SkeletonShapes', () {
    testWidgets('dashboardCard produces container with height 120',
        (tester) async {
      await tester.pumpWidget(
        buildApp(
          SizedBox(
            width: 300,
            child: SkeletonShapes.dashboardCard(theme: theme),
          ),
        ),
      );

      // Verify rendered size matches spec
      final size = tester.getSize(find.byType(Container).last);
      expect(size.height, 120);
    });

    testWidgets('listItem produces container with height 72', (tester) async {
      await tester.pumpWidget(
        buildApp(
          SizedBox(
            width: 300,
            child: SkeletonShapes.listItem(theme: theme),
          ),
        ),
      );

      final size = tester.getSize(find.byType(Container).last);
      expect(size.height, 72);
    });

    testWidgets('chartBlock produces container with height 200',
        (tester) async {
      await tester.pumpWidget(
        buildApp(
          SizedBox(
            width: 300,
            child: SkeletonShapes.chartBlock(theme: theme),
          ),
        ),
      );

      final size = tester.getSize(find.byType(Container).last);
      expect(size.height, 200);
    });
  });
}
