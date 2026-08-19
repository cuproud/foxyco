import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/play_update_service.dart';
import '../theme/tokens.dart';

class PlayUpdatePrompt extends ConsumerWidget {
  const PlayUpdatePrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(playUpdateProvider);
    if (update.state == PlayUpdateState.idle ||
        update.state == PlayUpdateState.failure ||
        update.state == PlayUpdateState.notAllowed) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(playUpdateProvider.notifier);
    final downloading =
        update.state == PlayUpdateState.starting ||
        update.state == PlayUpdateState.downloading;
    final downloaded = update.state == PlayUpdateState.downloaded;
    final progressLabel = update.progress == null
        ? 'Updating FoxyCo…'
        : 'Updating FoxyCo… ${(update.progress! * 100).round()}%';

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        decoration: BoxDecoration(
          color: FoxColors.bgSurface2,
          borderRadius: BorderRadius.circular(Radii.cardSm),
          border: Border.all(color: FoxColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              downloaded
                  ? 'FoxyCo update ready'
                  : downloading
                  ? progressLabel
                  : 'FoxyCo update available',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (downloading && update.progress != null) ...[
              const SizedBox(height: Gap.sm),
              LinearProgressIndicator(value: update.progress),
            ],
            if (!downloading) ...[
              const SizedBox(height: Gap.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('play-update-later'),
                      onPressed: controller.later,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FoxColors.textPrimary,
                        side: BorderSide(color: FoxColors.borderSoft),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.field),
                        ),
                      ),
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: FilledButton(
                      key: ValueKey(
                        downloaded
                            ? 'play-update-restart'
                            : 'play-update-start',
                      ),
                      onPressed: downloaded
                          ? controller.complete
                          : controller.startFlexible,
                      style: FilledButton.styleFrom(
                        backgroundColor: FoxColors.brandFox,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.field),
                        ),
                      ),
                      child: Text(downloaded ? 'Restart now' : 'Update now'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
