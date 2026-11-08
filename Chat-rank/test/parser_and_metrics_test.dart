import 'package:chat_rank/metrics/leaderboard.dart';
import 'package:chat_rank/metrics/metrics_engine.dart';
import 'package:chat_rank/models/chat_message.dart';
import 'package:chat_rank/parser/whatsapp_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WhatsAppParser', () {
    test('Android 24h export: system line, multi-line body, media', () {
      final chat = WhatsAppParser.parse([
        '12/03/2024, 14:05 - Messages and calls are end-to-end encrypted. '
            'No one outside of this chat, not even WhatsApp, can read or '
            'listen to them. Tap to learn more.',
        '12/03/2024, 14:05 - Jonathan: Hi there',
        '12/03/2024, 14:07 - Sam: Hey!',
        '13/03/2024, 09:00 - Sam: Are you free',
        'later today?',
        '13/03/2024, 09:30 - Jonathan: <Media omitted>',
      ].join('\n'));

      expect(chat.messages.length, 4);
      expect(chat.systemLines, 1);
      expect(chat.participants, {'Jonathan', 'Sam'});
      expect(chat.messages[0].timestamp, DateTime(2024, 3, 12, 14, 5));
      expect(chat.messages[2].body, 'Are you free\nlater today?');
      expect(chat.messages[3].isMedia, isTrue);
    });

    test('Android 12h export with narrow no-break space, month-first', () {
      final chat = WhatsAppParser.parse([
        '3/12/24, 2:05 PM - Sam: Hello',
        '3/25/24, 11:59 PM - Jonathan: Night',
        '3/26/24, 12:00 AM - Sam: Midnight',
      ].join('\n'));

      expect(chat.messages.length, 3);
      expect(chat.messages[0].timestamp, DateTime(2024, 3, 12, 14, 5));
      expect(chat.messages[1].timestamp, DateTime(2024, 3, 25, 23, 59));
      expect(chat.messages[2].timestamp, DateTime(2024, 3, 26, 0, 0));
    });

    test('iOS bracket format with invisible direction marks', () {
      final chat = WhatsAppParser.parse([
        '[12/03/2024, 14:05:33] Sam: Hey',
        '‎[13/03/2024, 14:06:10] Jonathan: Yo',
        '‎[13/03/2024, 14:07:00] Sam: ‎image omitted',
      ].join('\n'));

      expect(chat.messages.length, 3);
      expect(chat.messages[0].timestamp, DateTime(2024, 3, 12, 14, 5, 33));
      expect(chat.messages[1].sender, 'Jonathan');
      expect(chat.messages[2].isMedia, isTrue);
    });

    test('ambiguous dates default to day-first, overridable', () {
      const text = '01/02/2024, 10:00 - A: x';
      expect(WhatsAppParser.parse(text).messages.single.timestamp,
          DateTime(2024, 2, 1, 10));
      expect(
          WhatsAppParser.parse(text, dayFirstWhenAmbiguous: false)
              .messages
              .single
              .timestamp,
          DateTime(2024, 1, 2, 10));
    });

    test('chat name from file name', () {
      expect(WhatsAppParser.chatNameFromFileName('WhatsApp Chat with Sam.txt'),
          'Sam');
      expect(
          WhatsAppParser.chatNameFromFileName('WhatsApp Chat - Family Group.zip'),
          'Family Group');
      expect(
          WhatsAppParser.chatNameFromFileName('WhatsApp Chat with Sam (1).txt'),
          'Sam');
    });
  });

  group('MetricsEngine', () {
    ChatMessage msg(String sender, DateTime t) =>
        ChatMessage(timestamp: t, sender: sender, body: 'x');

    test('counts and median response times, ignoring gaps over the cap', () {
      final stats = const MetricsEngine().compute(
        chatName: 'Sam',
        selfName: 'Me',
        messages: [
          msg('Me', DateTime(2024, 3, 12, 10, 0)),
          msg('Sam', DateTime(2024, 3, 12, 10, 10)),
          msg('Sam', DateTime(2024, 3, 12, 10, 12)),
          msg('Me', DateTime(2024, 3, 12, 10, 15)),
          msg('Sam', DateTime(2024, 3, 14, 10, 0)),
        ],
      );

      expect(stats.sent, 2);
      expect(stats.received, 3);
      expect(stats.theirMedianResponse, const Duration(minutes: 10));
      expect(stats.myMedianResponse, const Duration(minutes: 3));
      expect(stats.balance, closeTo(0.8, 1e-9));
    });
  });

  group('Leaderboard', () {
    test('ranks busy, balanced, fast chats first', () {
      const a = ContactStats(
        chatName: 'A',
        sent: 50,
        received: 50,
        myMedianResponse: Duration(minutes: 5),
        theirMedianResponse: Duration(minutes: 5),
      );
      const b = ContactStats(chatName: 'B', sent: 10, received: 0);

      final board = buildLeaderboard([b, a]);

      expect(board.first.stats.chatName, 'A');
      expect(board.first.rank, 1);
      expect(board.first.score, closeTo(0.957, 0.001));
      expect(board.last.stats.chatName, 'B');
      expect(board.last.score, closeTo(0.05, 0.001));
    });
  });
}
