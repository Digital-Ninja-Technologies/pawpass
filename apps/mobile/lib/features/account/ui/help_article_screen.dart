import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../domain/help_content.dart';

/// One help article (design/screens/HelpArticle.dc.html).
class HelpArticleScreen extends StatefulWidget {
  const HelpArticleScreen({super.key, required this.articleId});
  final String articleId;

  @override
  State<HelpArticleScreen> createState() => _HelpArticleScreenState();
}

class _HelpArticleScreenState extends State<HelpArticleScreen> {
  bool? _helpful;

  @override
  Widget build(BuildContext context) {
    final doc = helpDocById(widget.articleId);
    if (doc == null) {
      return Scaffold(
        backgroundColor: PawColors.ground,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(PawSpace.screenSide),
                child: BookingHeader('Help article'),
              ),
              Expanded(
                child: PawErrorState(
                  title: 'We could not find that article',
                  message: 'It may have moved. Browse the help articles instead.',
                  actionLabel: 'Browse help articles',
                  onAction: () => context.go('/help/articles'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final related = [
      for (final id in doc.related) ?helpDocById(id),
    ];
    return Scaffold(
      backgroundColor: PawColors.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            PawSpace.screenSide,
            12,
            PawSpace.screenSide,
            32,
          ),
          children: [
            BookingHeader(doc.topic.label),
            const SizedBox(height: 18),
            Semantics(
              header: true,
              child: Text(doc.title, style: PawText.title28),
            ),
            const SizedBox(height: 6),
            Text(
              '${doc.minutes} minute read',
              style: PawText.meta12.copyWith(color: PawColors.muted),
            ),
            const SizedBox(height: 14),
            Text(
              doc.intro,
              style: PawText.body15.copyWith(
                color: PawColors.ink2,
                height: 1.5,
              ),
            ),
            if (doc.steps.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (var i = 0; i < doc.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: PawColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: PawText.body14Strong.copyWith(
                              color: PawColors.primaryText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.steps[i].title,
                              style: PawText.body15Strong,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              doc.steps[i].text,
                              style: PawText.body14.copyWith(
                                color: PawColors.ink2,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (doc.callout != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PawColors.warmSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PawIcon(
                      PawIconData.alertTriangle,
                      size: 18,
                      color: PawColors.warmText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        doc.callout!,
                        style: PawText.body14Strong.copyWith(
                          color: PawColors.warmText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            PawCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Was this helpful?', style: PawText.body15Strong),
                  const SizedBox(height: 10),
                  if (_helpful == null)
                    Row(
                      children: [
                        Expanded(
                          child: PawButton(
                            label: 'Yes',
                            variant: PawButtonVariant.secondary,
                            height: 44,
                            onPressed: () => setState(() => _helpful = true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PawButton(
                            label: 'Not really',
                            variant: PawButtonVariant.secondary,
                            height: 44,
                            onPressed: () => setState(() => _helpful = false),
                          ),
                        ),
                      ],
                    )
                  else if (_helpful!)
                    Text(
                      'Glad it helped.',
                      style: PawText.body14.copyWith(color: PawColors.ink2),
                    )
                  else ...[
                    Text(
                      'Sorry about that. Write to the team and we will sort it out.',
                      style: PawText.body14.copyWith(color: PawColors.ink2),
                    ),
                    const SizedBox(height: 10),
                    PawButton(
                      label: 'Contact the team',
                      height: 44,
                      expand: false,
                      onPressed: () => context.go('/help'),
                    ),
                  ],
                ],
              ),
            ),
            if (related.isNotEmpty) ...[
              const SizedBox(height: 18),
              const SectionLabel('Related'),
              const SizedBox(height: 4),
              for (final r in related)
                PawListRow(
                  title: r.title,
                  subtitle: r.summary,
                  showDivider: r != related.last,
                  onTap: () => context.push('/help/article/${r.id}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
