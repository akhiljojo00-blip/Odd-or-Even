import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/app/router.dart';
import 'package:odd_or_even/features/game/presentation/widgets/number_pad.dart';
import 'package:odd_or_even/features/home/presentation/screens/home_screen.dart';
import 'package:odd_or_even/features/offline/presentation/screens/offline_setup_screen.dart';
import 'package:odd_or_even/features/vs_computer/presentation/screens/vs_computer_setup_screen.dart';

void main() {
  group('NumberPad Dynamic Range Widget Tests', () {
    testWidgets('NumberPad with maxNumber = 6 renders 1 through 6 and excludes 7 through 10', (tester) async {
      int? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return NumberPad(
                  maxNumber: 6,
                  selectedNumber: selected,
                  onNumberSelected: (n) => setState(() => selected = n),
                  onConfirm: () {},
                );
              },
            ),
          ),
        ),
      );

      // Buttons 1-6 are present
      for (int i = 1; i <= 6; i++) {
        expect(find.text('$i'), findsOneWidget);
      }

      // Buttons 7-10 are NOT present
      for (int i = 7; i <= 10; i++) {
        expect(find.text('$i'), findsNothing);
      }

      // Label displays range (1 - 6)
      expect(find.text('SELECT A NUMBER (1 - 6)'), findsOneWidget);
    });

    testWidgets('NumberPad with maxNumber = 10 renders 1 through 10', (tester) async {
      int? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return NumberPad(
                  maxNumber: 10,
                  selectedNumber: selected,
                  onNumberSelected: (n) => setState(() => selected = n),
                  onConfirm: () {},
                );
              },
            ),
          ),
        ),
      );

      // All 10 buttons present
      for (int i = 1; i <= 10; i++) {
        expect(find.text('$i'), findsOneWidget);
      }

      // Label displays range (1 - 10)
      expect(find.text('SELECT A NUMBER (1 - 10)'), findsOneWidget);
    });
  });

  group('Setup Screens & Home Widget Tests', () {
    testWidgets('VsComputerSetupScreen renders difficulty, range, and start button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VsComputerSetupScreen(),
          ),
        ),
      );

      expect(find.text('VS COMPUTER SETUP'), findsOneWidget);
      expect(find.text('AI DIFFICULTY'), findsOneWidget);
      expect(find.text('EASY'), findsOneWidget);
      expect(find.text('MEDIUM'), findsOneWidget);
      expect(find.text('HARD'), findsOneWidget);
      expect(find.text('1 – 6 (DEFAULT)'), findsOneWidget);
      expect(find.text('1 – 10 (CLASSIC)'), findsOneWidget);
      expect(find.text('START VS COMPUTER'), findsOneWidget);
    });

    testWidgets('OfflineSetupScreen renders Number Selection Range chips', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OfflineSetupScreen(),
          ),
        ),
      );

      expect(find.text('NUMBER SELECTION RANGE'), findsOneWidget);
      expect(find.text('1 – 6 (DEFAULT)'), findsOneWidget);
      expect(find.text('1 – 10 (CLASSIC)'), findsOneWidget);
      expect(find.text('START MATCH'), findsOneWidget);
    });

    testWidgets('HomeScreen renders VS COMPUTER mode card alongside Pass & Play and Online', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      expect(find.text('ODD OR EVEN'), findsOneWidget);
      expect(find.text('PASS & PLAY'), findsOneWidget);
      expect(find.text('VS COMPUTER'), findsOneWidget);
      expect(find.text('ONLINE ROOMS'), findsOneWidget);
      expect(find.text('QUICK MATCH'), findsOneWidget);
    });

    testWidgets('Navigation Flow: Home -> VS Computer Setup -> VS Computer Gameplay', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Home screen shows VS COMPUTER card
      expect(find.text('VS COMPUTER'), findsOneWidget);

      // 2. Tap VS Computer card
      await tester.ensureVisible(find.text('VS COMPUTER'));
      await tester.pump();
      await tester.tap(find.text('VS COMPUTER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 3. Reaches VS Computer Setup Screen
      expect(find.text('VS COMPUTER SETUP'), findsOneWidget);
      expect(find.text('START VS COMPUTER'), findsOneWidget);

      // 4. Tap Start VS Computer button
      await tester.ensureVisible(find.text('START VS COMPUTER'));
      await tester.pump();
      await tester.tap(find.text('START VS COMPUTER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 5. Reaches VS Computer Gameplay Screen in Toss Phase
      expect(find.text('COIN TOSS DUEL'), findsOneWidget);
    });

    testWidgets('Navigation Flow: Home -> Pass & Play Setup', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(find.text('PASS & PLAY'));
      await tester.pump();
      await tester.tap(find.text('PASS & PLAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('MATCH CONFIGURATION'), findsOneWidget);
    });

    testWidgets('Navigation Flow: Home -> Online Rooms Lobby', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(find.text('ONLINE ROOMS'));
      await tester.pump();
      await tester.tap(find.text('ONLINE ROOMS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ONLINE MULTIPLAYER'), findsOneWidget);
    });

    testWidgets('Navigation Flow: Home -> Quick Match', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(find.text('QUICK MATCH'));
      await tester.pump();
      await tester.tap(find.text('QUICK MATCH'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('FINDING OPPONENT'), findsOneWidget);
    });
  });
}
