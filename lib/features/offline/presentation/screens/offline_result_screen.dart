import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/widgets/creator_footer.dart';
import '../../../game/presentation/widgets/match_result_view.dart';
import '../controllers/offline_game_controller.dart';

class OfflineResultScreen extends ConsumerWidget {
  const OfflineResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineState = ref.watch(offlineGameProvider);
    final match = offlineState.match;

    return Scaffold(
      backgroundColor: GameColors.background,
      bottomNavigationBar: const CreatorFooter(padding: EdgeInsets.only(top: 4, bottom: 6)),
      body: Container(
        decoration: const BoxDecoration(
          gradient: GameColors.arcadeBackgroundGradient,
        ),
        child: SafeArea(
          child: MatchResultView(
            match: match,
            currentUserId: null, // Pass & Play celebrates the match winner
            onRematch: () {
              ref.read(offlineGameProvider.notifier).requestRematch();
              context.go('/offline-play');
            },
            onHome: () {
              context.go('/');
            },
          ),
        ),
      ),
    );
  }
}
