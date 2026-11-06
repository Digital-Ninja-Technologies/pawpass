import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../domain/help_content.dart';

/// Help articles by topic, with search (design/screens/HelpArticles.dc.html).
class HelpArticlesScreen extends StatefulWidget {
  const HelpArticlesScreen({super.key});

  @override
  State<HelpArticlesScreen> createState() => _HelpArticlesScreenState();
}

class _HelpArticlesScreenState extends State<HelpArticlesScreen> {
  final _search = TextEditingController();
  HelpTopic? _topic;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawColors.ground,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _search,
          builder: (context, _) {
            final q = _search.text.trim();
            final results = searchHelp(q);
            final searching = q.isNotEmpty;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                PawSpace.screenSide,
                12,
                PawSpace.screenSide,
                32,
              ),
              children: [
                const BookingHeader('Help articles'),
                const SizedBox(height: 14),
                PawTextField(
                  label: 'Search help',
                  controller: _search,
                  hint: 'Search help articles',
                  textInputAction: TextInputAction.search,
                ),
                const SizedBox(height: 16),
                if (searching) ...[
                  if (results.isEmpty)
                    SizedBox(
                      height: 360,
                      child: PawEmptyState(
                        icon: PawIconData.search,
                        tone: PawStateTone.neutral,
                        title: 'We found nothing for that',
                        message:
                            'Try a shorter word, or check the spelling. You can also browse by topic.',
                        actionLabel: 'Clear search',
                        onAction: _search.clear,
                      ),
                    )
                  else ...[
                    SectionLabel(
                      '${results.length} ${results.length == 1 ? 'article' : 'articles'}',
                    ),
                    const SizedBox(height: 4),
                    for (final d in results)
                      _ArticleRow(doc: d, last: d == results.last),
                  ],
                ] else ...[
                  const SectionLabel('Browse by topic'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PawChip(
                        label: 'All',
                        selected: _topic == null,
                        onTap: () => setState(() => _topic = null),
                      ),
                      for (final t in HelpTopic.values)
                        PawChip(
                          label: '${t.label} · ${helpForTopic(t).length}',
                          selected: _topic == t,
                          onTap: () => setState(() => _topic = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SectionLabel(_topic == null ? 'Most read' : _topic!.label),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final list = _topic == null
                          ? [for (final d in helpDocs) if (d.popular) d]
                          : helpForTopic(_topic!);
                      return Column(
                        children: [
                          for (final d in list)
                            _ArticleRow(doc: d, last: d == list.last),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/help'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(PawSize.touch, PawSize.touch),
                    ),
                    child: Text(
                      "Can't find it? Contact the team",
                      style: PawText.body14Strong.copyWith(
                        color: PawColors.primaryText,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ArticleRow extends StatelessWidget {
  const _ArticleRow({required this.doc, required this.last});
  final HelpDoc doc;
  final bool last;

  @override
  Widget build(BuildContext context) => PawListRow(
    title: doc.title,
    subtitle: doc.summary,
    showDivider: !last,
    onTap: () => context.push('/help/article/${doc.id}'),
  );
}
