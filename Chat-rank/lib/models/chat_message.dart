/// A single user-authored message from a WhatsApp chat export.
class ChatMessage {
  const ChatMessage({
    required this.timestamp,
    required this.sender,
    required this.body,
    this.isMedia = false,
  });

  /// Local wall-clock time as written in the export (exports carry no time zone).
  final DateTime timestamp;
  final String sender;
  final String body;

  /// True for placeholders such as "<Media omitted>" or "image omitted".
  final bool isMedia;

  /// Stable key used to skip duplicates when the same chat is re-exported.
  String get dedupeKey => '${timestamp.toIso8601String()}|$sender|$body';
}

/// The result of parsing one exported chat file.
class ParsedChat {
  const ParsedChat({required this.messages, required this.systemLines});

  final List<ChatMessage> messages;

  /// Number of header lines skipped because they were system notices
  /// (encryption banner, "X joined", etc.) rather than user messages.
  final int systemLines;

  Set<String> get participants => messages.map((m) => m.sender).toSet();
}
