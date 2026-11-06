import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/domain/booking_logic.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/community_logic.dart';
import '../domain/models.dart';
import '../state/chat_controller.dart';

/// Chat (design/screens/Chat.dc.html): a conversation about a lost pet. Phone numbers are never shown.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  var _started = false;
  var _lastCount = 0;
  ChatController? _chat;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _chat?.close();
    super.dispose();
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final chat = _chat = scope.chat;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => chat.open(widget.conversationId),
      );
    }
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        final h = chat.header;
        if (chat.messages.length != _lastCount) {
          _lastCount = chat.messages.length;
          _toEnd();
        }
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PawSpace.screenSide,
                    12,
                    PawSpace.screenSide,
                    8,
                  ),
                  child: Row(
                    children: [
                      const PawBackButton(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                h?.otherName ?? 'Chat',
                                style: PawText.heading22,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (h != null)
                              Text(
                                'About: ${h.contextLabel}',
                                style: PawText.meta13.copyWith(
                                  color: PawColors.muted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: PawColors.primarySoft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: PawSpace.screenSide,
                    vertical: 10,
                  ),
                  child: Text(
                    'Phone numbers stay hidden. Chat here, and share a location pin if it helps.',
                    style: PawText.meta13.copyWith(
                      color: PawColors.primaryText,
                    ),
                  ),
                ),
                Expanded(
                  child: chat.loadingMessages && chat.messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : chat.messagesError != null && h == null
                      ? LoadError(
                          message: chat.messagesError!,
                          onRetry: () => chat.open(widget.conversationId),
                        )
                      : chat.messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'Say hello. Tell ${h?.otherName ?? 'them'} what you saw.',
                              textAlign: TextAlign.center,
                              style: PawText.body15.copyWith(
                                color: PawColors.muted,
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(
                            PawSpace.screenSide,
                            12,
                            PawSpace.screenSide,
                            12,
                          ),
                          children: [
                            for (final m in chat.messages)
                              _Bubble(message: m, now: chat.now),
                          ],
                        ),
                ),
                if (chat.sendError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PawSpace.screenSide,
                      vertical: 4,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        chat.sendError!,
                        style: PawText.meta13.copyWith(color: PawColors.danger),
                      ),
                    ),
                  ),
                Container(
                  decoration: const BoxDecoration(
                    color: PawColors.surface,
                    border: Border(top: BorderSide(color: PawColors.border)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      RoundIconButton(
                        icon: PawIconData.mapPin,
                        semanticLabel: 'Share my location',
                        onPressed: chat.sending ? () {} : chat.shareLocation,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _text,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          style: PawText.body15,
                          decoration: InputDecoration(
                            hintText: 'Message',
                            counterText: '',
                            filled: true,
                            fillColor: PawColors.subtle,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      RoundIconButton(
                        icon: PawIconData.chevronRight,
                        filled: true,
                        semanticLabel: 'Send message',
                        onPressed: () async {
                          final text = _text.text;
                          if (text.trim().isEmpty) {
                            return;
                          }
                          final ok = await chat.send(text);
                          if (ok) {
                            _text.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.now});
  final ChatMessage message;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final links = AppScope.of(context).services.links;
    final bg = m.mine ? PawColors.primary : PawColors.surface;
    final fg = m.mine ? Colors.white : PawColors.ink;
    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Semantics(
          container: true,
          label:
              '${m.mine ? 'You' : 'They'}: ${m.isLocation ? 'shared a location' : m.body ?? ''}. ${timeAgoShort(m.createdAt, now)}',
          excludeSemantics: true,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: m.mine ? null : Border.all(color: PawColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.body != null)
                  Text(
                    m.body!,
                    style: PawText.body15.copyWith(color: fg, height: 1.4),
                  ),
                if (m.isLocation) ...[
                  if (m.body != null) const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PawIcon(PawIconData.mapPin, size: 18, color: fg),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Shared location',
                          style: PawText.body14Strong.copyWith(color: fg),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => links.open(mapsUri(m.lat!, m.lng!)),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: PawSize.touch,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: 1,
                        child: Text(
                          'Open in Maps',
                          style: PawText.meta13.copyWith(
                            color: fg,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  timeLabel(m.createdAt),
                  style: PawText.meta12.copyWith(
                    color: m.mine ? Colors.white70 : PawColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The inbox: every conversation, newest first, with an unread dot.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.embedded = false});

  /// True when it is a tab (partner mode): no back button.
  final bool embedded;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final chat = AppScope.of(context).chat;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => chat.loadThreads());
    }
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: chat.loadThreads,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  PawSpace.screenSide,
                  12,
                  PawSpace.screenSide,
                  32,
                ),
                children: [
                  Row(
                    children: [
                      if (!widget.embedded) ...[
                        const PawBackButton(),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text('Messages', style: PawText.heading22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (chat.loadingThreads && !chat.threadsLoaded)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (chat.threadsError != null && !chat.threadsLoaded)
                    LoadError(
                      message: chat.threadsError!,
                      onRetry: chat.loadThreads,
                    )
                  else if (chat.threads.isEmpty)
                    const InfoCard(
                      title: 'No messages yet',
                      body: 'When you message about a lost pet, or someone messages you, it shows up here.',
                      icon: PawIconData.mail,
                    )
                  else
                    for (final t in chat.threads)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PawCard(
                          radius: PawRadius.cardSmall,
                          onTap: () async {
                            await context.push('/chat/${t.id}');
                            await chat.loadThreads();
                          },
                          semanticLabel:
                              '${t.otherName}, ${t.contextLabel}${t.unread > 0 ? ', ${t.unread} unread' : ''}',
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.otherName,
                                      style: PawText.body15Strong,
                                    ),
                                    Text(
                                      t.contextLabel,
                                      style: PawText.meta13.copyWith(
                                        color: PawColors.muted,
                                      ),
                                    ),
                                    if (t.lastBody != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          t.lastBody!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: PawText.meta13.copyWith(
                                            color: PawColors.ink2,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (t.unread > 0)
                                Container(
                                  key: const Key('unread-dot'),
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: PawColors.dot,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
