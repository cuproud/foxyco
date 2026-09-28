import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/session_summary.dart';
import '../../services/session_log.dart';
import '../home/recap_widgets.dart';
import '../settings/settings_controller.dart';
import '../theme/tokens.dart';

class SessionHistoryScreen extends ConsumerStatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  ConsumerState<SessionHistoryScreen> createState() =>
      _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends ConsumerState<SessionHistoryScreen> {
  final _scrollController = ScrollController();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final threshold = MediaQuery.sizeOf(context).height * 1.1;
    final show =
        _scrollController.hasClients && _scrollController.offset > threshold;
    if (show != _showBackToTop && mounted) {
      setState(() => _showBackToTop = show);
    }
  }

  void _backToTop() => _scrollController.animateTo(
    0,
    duration: Motion.morph,
    curve: Motion.curve,
  );

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionLogProvider);
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Session history')),
      body: sessions.isEmpty
          ? const Center(child: Text('No completed sessions yet.'))
          : Stack(
              children: [
                ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    Gap.md,
                    Gap.sm,
                    Gap.md,
                    Gap.xl,
                  ),
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
                  itemBuilder: (context, index) => _SessionRow(
                    session: sessions[index],
                    currency: settings.currency.symbol,
                  ),
                ),
                Positioned(
                  right: Gap.md,
                  bottom: MediaQuery.of(context).padding.bottom + Gap.md,
                  child: AnimatedSwitcher(
                    duration: Motion.base,
                    child: _showBackToTop
                        ? Material(
                            key: const ValueKey('session_back_to_top'),
                            color: FoxColors.bgSurface,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: IconButton(
                              tooltip: 'Back to top',
                              onPressed: _backToTop,
                              icon: const Icon(Icons.arrow_upward_rounded),
                              color: FoxColors.brandFox,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.currency});

  final SessionSummary session;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final rate = session.acceptanceRate;
    final start = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(session.startedAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final end = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(session.endedAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return Container(
      key: ValueKey('session-${session.endedAt.microsecondsSinceEpoch}'),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: FoxColors.ink,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.formatMediumDate(session.endedAt),
                      style: TextStyle(
                        color: FoxColors.cream,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$start - $end',
                      style: TextStyle(color: FoxColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                durationLabel(session.duration),
                style: TextStyle(
                  color: FoxColors.cream,
                  fontFamily: FoxFonts.display,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              _Metric(value: '${session.total}', label: 'scored'),
              _Metric(value: '${session.accepted}', label: 'accepted'),
              _Metric(
                value: rate == null ? '-' : '${(rate * 100).round()}%',
                label: 'known accept',
              ),
              _Metric(
                value: '$currency${session.earnings.toStringAsFixed(0)}',
                label: 'recorded',
                valueColor: FoxColors.brandFox,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, this.valueColor});

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? FoxColors.cream,
              fontFamily: FoxFonts.display,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: FoxColors.textSecondary, fontSize: 10.5),
        ),
      ],
    ),
  );
}
