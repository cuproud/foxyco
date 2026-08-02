import 'package:flutter/material.dart';

import '../legal/legal_links.dart';
import '../theme/tokens.dart';
import 'about_content.dart';

/// About FoxyCo — what the app does, what it stores, and how to unstick it.
///
/// Deliberately dumb: it renders [aboutSections] and nothing else. All the copy
/// lives in `about_content.dart`, so growing the FAQ never touches this file.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl),
        children: [
          // The wordmark IS the name — no icon-plus-"FoxyCo" pair beside it.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/branding/foxyco_logo.png',
                width: 156,
                semanticLabel: 'FoxyCo',
              ),
              Text(
                aboutVersion,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FoxColors.textDisabled,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(
            aboutIntro,
            style: text.bodyMedium?.copyWith(
              color: FoxColors.textSecondary,
              height: 1.45,
            ),
          ),
          for (final section in aboutSections) ...[
            const SizedBox(height: Gap.lg),
            Text(section.title.toUpperCase(), style: text.labelSmall),
            if (section.blurb.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              Text(
                section.blurb,
                style: text.bodyMedium?.copyWith(
                  color: FoxColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: Gap.sm),
            _SectionCard(entries: section.entries),
          ],
          const SizedBox(height: Gap.lg),
          const LegalFooter(),
        ],
      ),
    );
  }
}

/// One group of questions as a single card of expansion tiles, hairline-divided.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.entries});
  final List<AboutEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: FoxColors.borderSoft),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) Divider(height: 1, color: FoxColors.borderSoft),
            _EntryTile(entry: entries[i]),
          ],
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final AboutEntry entry;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // ExpansionTile draws its own divider lines; the card supplies them.
      data: Theme.of(
        context,
      ).copyWith(dividerColor: Colors.transparent, splashColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: Gap.md),
        childrenPadding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: FoxColors.brandFox,
        collapsedIconColor: FoxColors.textDisabled,
        title: Text(
          entry.question,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: FoxColors.textPrimary,
          ),
        ),
        children: [
          Text(
            entry.answer,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: FoxColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
