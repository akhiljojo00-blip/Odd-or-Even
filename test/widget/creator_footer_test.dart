import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/core/widgets/creator_footer.dart';

void main() {
  group('CreatorFooter Widget Tests', () {
    testWidgets('Renders exact creator signature and Instagram handle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreatorFooter(),
          ),
        ),
      );

      expect(find.byType(CreatorFooter), findsOneWidget);

      // Verify exact text contents
      expect(find.textContaining('ig - '), findsOneWidget);
      expect(find.textContaining('@__refle_xoo_7'), findsOneWidget);
      expect(find.textContaining('Created By '), findsOneWidget);
      expect(find.textContaining('Akhil Jojo'), findsOneWidget);
    });

    testWidgets('Adapts to wide horizontal layout on desktop/tablet/standard phones', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreatorFooter(),
          ),
        ),
      );

      // Should be arranged in a Row
      expect(find.descendant(of: find.byType(CreatorFooter), matching: find.byType(Row)), findsOneWidget);
      expect(find.descendant(of: find.byType(CreatorFooter), matching: find.byType(Column)), findsNothing);
    });

    testWidgets('Adapts to stacked layout on ultra-narrow viewport without overflow', (tester) async {
      tester.view.physicalSize = const Size(280, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreatorFooter(),
          ),
        ),
      );

      // On narrow viewport (<320), it stacks into a Column
      expect(find.descendant(of: find.byType(CreatorFooter), matching: find.byType(Column)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
