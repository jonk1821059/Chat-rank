import '../models/chat_message.dart';

/// Per-chat statistics from the point of view of the app's user.
class ContactStats {
  const ContactStats({
    required this.chatName,
    required this.sent,
    required this.received,
    this.myMedianResponse,
    this.theirMedianResponse,
    this.firstMessage,
    this.lastMessage,
  });

  final String chatName;
  final int sent;
  final int received;

  /// Median time the user takes to reply after the other side wrote.
  final Duration? myMedianResponse;

  /// Median time the other side takes to reply after the user wrote.
  final Duration? theirMedianResponse;
  final DateTime? firstMessage;
  final DateTime? lastMessage;

  int get total => sent + received;

  /// 1.0 = perfectly even conversation, 0.0 = completely one-sided.
  double get balance => total == 0 ? 0 : 1 - (sent - received).abs() / total;
}

class MetricsEngine {
  const MetricsEngine({this.responseCap = const Duration(hours: 12)});

  /// Gaps longer than this are treated as a new conversation, not a slow
  /// reply, so overnight silences don't wreck the response-time medians.
  final Duration responseCap;

  /// A "response" is the gap between the last message on one side and the
  /// first message of the other side that follows it.
  ContactStats compute({
    required String chatName,
    required List<ChatMessage> messages,
    required String selfName,
  }) {
    // Order by time, keeping original order for identical timestamps.
    final order = List<int>.generate(messages.length, (i) => i)
      ..sort((a, b) {
        final c = messages[a].timestamp.compareTo(messages[b].timestamp);
        return c != 0 ? c : a.compareTo(b);
      });

    var sent = 0;
    var received = 0;
    final mine = <Duration>[];
    final theirs = <Duration>[];
    ChatMessage? prev;
    DateTime? first;
    DateTime? last;

    for (final i in order) {
      final m = messages[i];
      final isMe = m.sender == selfName;
      if (isMe) {
        sent++;
      } else {
        received++;
      }
      if (prev != null) {
        final prevIsMe = prev.sender == selfName;
        if (isMe != prevIsMe) {
          final gap = m.timestamp.difference(prev.timestamp);
          if (gap <= responseCap) {
            (isMe ? mine : theirs).add(gap);
          }
        }
      }
      first ??= m.timestamp;
      last = m.timestamp;
      prev = m;
    }

    return ContactStats(
      chatName: chatName,
      sent: sent,
      received: received,
      myMedianResponse: _median(mine),
      theirMedianResponse: _median(theirs),
      firstMessage: first,
      lastMessage: last,
    );
  }

  static Duration? _median(List<Duration> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) ~/ 2;
  }
}
