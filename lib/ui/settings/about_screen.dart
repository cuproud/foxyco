import 'package:flutter/material.dart';

import '../legal/legal_links.dart';
import '../theme/tokens.dart';
import 'about_content.dart';

/// About FoxyCo — what the app does, what it stores, and how to unstick it.
///
/// Copy lives in `about_content.dart`; search filters it locally.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final query = _search.text.trim().toLowerCase();
    final sections = aboutSections
        .map((section) {
          final entries = section.entries
              .where(
                (entry) =>
                    section.title.toLowerCase().contains(query) ||
                    section.blurb.toLowerCase().contains(query) ||
                    entry.question.toLowerCase().contains(query) ||
                    entry.answer.toLowerCase().contains(query),
              )
              .toList();
          return AboutSection(
            title: section.title,
            blurb: section.blurb,
            entries: entries,
          );
        })
        .where((section) => section.entries.isNotEmpty)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Help & About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl),
        children: [
          // The wordmark IS the name — no icon-plus-"FoxyCo" pair beside it.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/branding/foxyco_logo.png',
                width: 128,
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
          const SizedBox(height: Gap.md),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Search help',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () => setState(_search.clear),
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          if (sections.isEmpty) ...[
            const SizedBox(height: Gap.lg),
            const Text(
              'No matching help. Try another word or clear the search.',
            ),
          ],
          for (final section in sections) ...[
            const SizedBox(height: Gap.md),
            Semantics(
              header: true,
              child: Text(section.title.toUpperCase(), style: text.labelSmall),
            ),
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
            _SectionCard(
              key: ValueKey(section.title),
              entries: section.entries,
            ),
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
  const _SectionCard({super.key, required this.entries});
  final List<AboutEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Material(
      clipBehavior: Clip.antiAlias,
      color: FoxColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: FoxColors.borderSoft),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) Divider(height: 1, color: FoxColors.borderSoft),
            _EntryTile(key: ValueKey(entries[i].question), entry: entries[i]),
          ],
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({super.key, required this.entry});
  final AboutEntry entry;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // ExpansionTile draws its own divider lines; the card supplies them.
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: ExpansionTile(
        key: PageStorageKey(entry.question),
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
