import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../onboarding/data/repositories.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/session_controller.dart';
import '../domain/models.dart';

/// The inbox and one open conversation, kept fresh through Supabase Realtime.
class ChatController extends ChangeNotifier {
  ChatController(this._services, this._session) {
    _session.addListener(_onSession);
  }

  final AppServices _services;
  final SessionController _session;
  var _disposed = false;

  DateTime get now => _services.now();

  // ------------------------------------------------------------------ inbox

  List<ChatThread> threads = const [];
  bool loadingThreads = false;
  bool threadsLoaded = false;
  String? threadsError;

  int get unread => threads.fold(0, (n, t) => n + t.unread);

  /// Message requests waiting for this person's answer.
  List<ChatThread> get requests => [
    for (final t in threads)
      if (t.needsMyAnswer) t,
  ];

  /// Everything else, newest first.
  List<ChatThread> get conversations => [
    for (final t in threads)
      if (!t.needsMyAnswer) t,
  ];

  Future<void> loadThreads() async {
    loadingThreads = true;
    threadsError = null;
    _notify();
    try {
      threads = await _services.community.threads();
      threadsLoaded = true;
    } on AppFailure catch (e) {
      threadsError = e.message;
    } finally {
      loadingThreads = false;
      _notify();
    }
  }

  // ------------------------------------------------------------------ one conversation

  String? openId;
  ChatThread? header;
  List<ChatMessage> messages = const [];
  bool loadingMessages = false;
  String? messagesError;
  String? sendError;
  bool sending = false;
  StreamSubscription<void>? _sub;

  Future<void> open(String conversationId) async {
    await _sub?.cancel();
    openId = conversationId;
    header = null;
    messages = const [];
    messagesError = null;
    sendError = null;
    loadingMessages = true;
    _notify();
    try {
      final results = await Future.wait([
        _services.community.thread(conversationId),
        _services.community.messages(conversationId),
      ]);
      header = results[0] as ChatThread;
      messages = results[1] as List<ChatMessage>;
      _sub = _services.community
          .watchMessages(conversationId)
          .listen((_) => _refresh());
      await _services.community.markRead(conversationId);
    } on AppFailure catch (e) {
      messagesError = e.message;
    } finally {
      loadingMessages = false;
      _notify();
    }
  }

  Future<void> _refresh() async {
    final id = openId;
    if (id == null) return;
    try {
      final latest = await _services.community.messages(id);
      if (openId != id) return;
      messages = latest;
      _notify();
      await _services.community.markRead(id);
    } on AppFailure {
      // The next message tries again.
    }
  }

  Future<bool> send(String text) async {
    final id = openId;
    if (id == null || sending) return false;
    final body = text.trim();
    if (body.isEmpty) return false;
    return _send(id, body: body);
  }

  /// Shares where the phone is now as a map pin in the chat.
  Future<bool> shareLocation() async {
    final id = openId;
    if (id == null || sending) return false;
    final here = await _services.location.current();
    if (here == null) {
      sendError = 'Turn on location to share where you are.';
      _notify();
      return false;
    }
    return _send(id, lat: here.lat, lng: here.lng);
  }

  Future<bool> _send(
    String id, {
    String? body,
    double? lat,
    double? lng,
  }) async {
    sending = true;
    sendError = null;
    _notify();
    try {
      await _services.community.sendMessage(id, body: body, lat: lat, lng: lng);
      messages = await _services.community.messages(id);
      return true;
    } on AppFailure catch (e) {
      sendError = e.message;
      return false;
    } finally {
      sending = false;
      _notify();
    }
  }

  // ------------------------------------------------------------------ message requests

  bool requesting = false;
  String? requestError;

  /// Asks a pet's owner to chat. Returns the conversation to open, or null if it did not go through.
  Future<String?> requestChat(String petId, String message) async {
    if (requesting) return null;
    requesting = true;
    requestError = null;
    _notify();
    try {
      final id = await _services.community.requestChat(petId, message);
      await loadThreads();
      return id;
    } on AppFailure catch (e) {
      requestError = e.message;
      return null;
    } finally {
      requesting = false;
      _notify();
    }
  }

  final _answering = <String>{};
  String? answerError;

  bool isAnswering(String requestId) => _answering.contains(requestId);

  /// Accepts or declines a request. Declined requests disappear from both people's lists.
  Future<bool> answerRequest(String requestId, {required bool accept}) async {
    if (!_answering.add(requestId)) return false;
    answerError = null;
    _notify();
    try {
      await _services.community.answerChatRequest(requestId, accept: accept);
      await loadThreads();
      final id = openId;
      if (id != null) {
        try {
          header = await _services.community.thread(id);
        } on AppFailure {
          // The chat may have gone (declined); the screen leaves on its own.
        }
      }
      return true;
    } on AppFailure catch (e) {
      answerError = e.message;
      return false;
    } finally {
      _answering.remove(requestId);
      _notify();
    }
  }

  /// Leaves the conversation: stops listening. (Screens refresh the inbox when they come back into view.)
  Future<void> close() async {
    final sub = _sub;
    _sub = null;
    openId = null;
    await sub?.cancel();
  }

  // ------------------------------------------------------------------ lifecycle

  void _onSession() {
    if (_disposed) return;
    if (_session.status == SessionStatus.signedOut) reset();
  }

  void reset() {
    _sub?.cancel();
    _sub = null;
    openId = null;
    threads = const [];
    threadsLoaded = false;
    messages = const [];
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _session.removeListener(_onSession);
    super.dispose();
  }
}
