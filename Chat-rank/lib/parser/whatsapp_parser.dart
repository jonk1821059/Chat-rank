import '../models/chat_message.dart';

enum _DateOrder { dmy, mdy, ymd }

class _RawEntry {
  _RawEntry(this.date, this.time, this.ampm, this.rest);

  final String date;
  final String time;
  final String? ampm;

  /// Everything after the timestamp; continuation lines are appended.
  String rest;
}

/// Parses WhatsApp "Export chat" text files from Android and iOS.
///
/// Handled variations:
///  * Android:  `12/03/2024, 14:05 - Sam: Hi`  and  `3/12/24, 2:05 PM - Sam: Hi`
///  * iOS:      `[12/03/2024, 14:05:33] Sam: Hi`
///  * Separators `/`, `.` or `-`; 12h or 24h clocks; narrow no-break spaces
///  * Multi-line messages, system notices, and "omitted" media placeholders
///  * Day-first vs month-first dates, inferred from the whole file
class WhatsAppParser {
  const WhatsAppParser._();

  static final RegExp _header = RegExp(
    r'^[‎‏﻿]*\[?(\d{1,4}[/.\-]\d{1,2}[/.\-]\d{1,4}),?\s+'
    r'(\d{1,2}[:.]\d{2}(?::\d{2})?)'
    r'(?:[\s  ]*([AaPp]\.?\s?[Mm]\.?))?'
    r'\]?(?:\s+-)?\s+(.*)$',
  );

  static final RegExp _dateSep = RegExp(r'[/.\-]');
  static final RegExp _timeSep = RegExp(r'[:.]');
  static final RegExp _invisible = RegExp(r'[‎‏﻿]');
  static final RegExp _media = RegExp(
    r'^(<media omitted>|<attached: .*>|'
    r'(image|video|audio|sticker|gif|document|contact card|video note) omitted|'
    r'.* \(file attached\))$',
    caseSensitive: false,
  );

  /// Parses [raw] export text.
  ///
  /// When every date in the file is ambiguous (all days and months <= 12) the
  /// order falls back to day-first unless [dayFirstWhenAmbiguous] is false.
  static ParsedChat parse(String raw, {bool dayFirstWhenAmbiguous = true}) {
    final lines =
        raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

    // Pass 1: group physical lines into logical entries.
    final entries = <_RawEntry>[];
    for (final line in lines) {
      final m = _header.firstMatch(line);
      if (m != null) {
        entries.add(_RawEntry(m.group(1)!, m.group(2)!, m.group(3), m.group(4) ?? ''));
      } else if (entries.isNotEmpty) {
        entries.last.rest += '\n$line';
      }
    }

    // Pass 2: decide the date order using the whole file.
    final order = _detectOrder(entries.map((e) => e.date), dayFirstWhenAmbiguous);

    // Pass 3: build messages.
    final messages = <ChatMessage>[];
    var systemLines = 0;
    for (final e in entries) {
      final timestamp = _buildDateTime(e.date, e.time, e.ampm, order);
      if (timestamp == null) {
        systemLines++;
        continue;
      }
      final cleaned = e.rest.replaceAll(_invisible, '');
      final newline = cleaned.indexOf('\n');
      final firstLine = newline == -1 ? cleaned : cleaned.substring(0, newline);
      final split = firstLine.indexOf(': ');
      if (split <= 0 || split > 60) {
        systemLines++;
        continue;
      }
      final sender = cleaned.substring(0, split).trim();
      final body = cleaned.substring(split + 2).trim();
      messages.add(ChatMessage(
        timestamp: timestamp,
        sender: sender,
        body: body,
        isMedia: _media.hasMatch(body),
      ));
    }
    return ParsedChat(messages: messages, systemLines: systemLines);
  }

  /// Extracts the chat name from an export file name, e.g.
  /// `WhatsApp Chat with Sam (1).txt` -> `Sam`.
  static String chatNameFromFileName(String fileName) {
    var name = fileName.split(RegExp(r'[\\/]')).last;
    name = name.replaceFirst(RegExp(r'\.(txt|zip)$', caseSensitive: false), '');
    name = name.replaceFirst(RegExp(r'\s*\(\d+\)$'), '');
    final m = RegExp(r'^WhatsApp Chat (?:with|-)\s+(.+)$', caseSensitive: false)
        .firstMatch(name);
    return (m?.group(1) ?? name).trim();
  }

  static _DateOrder _detectOrder(Iterable<String> dates, bool dayFirst) {
    var firstOver12 = false;
    var secondOver12 = false;
    for (final d in dates) {
      final parts = d.split(_dateSep);
      if (parts[0].length == 4) return _DateOrder.ymd;
      if (int.parse(parts[0]) > 12) firstOver12 = true;
      if (int.parse(parts[1]) > 12) secondOver12 = true;
    }
    if (firstOver12) return _DateOrder.dmy;
    if (secondOver12) return _DateOrder.mdy;
    return dayFirst ? _DateOrder.dmy : _DateOrder.mdy;
  }

  static DateTime? _buildDateTime(
      String date, String time, String? ampm, _DateOrder order) {
    final d = date.split(_dateSep).map(int.parse).toList();
    int year, month, day;
    if (order == _DateOrder.ymd) {
      year = d[0];
      month = d[1];
      day = d[2];
    } else if (order == _DateOrder.mdy) {
      month = d[0];
      day = d[1];
      year = d[2];
    } else {
      day = d[0];
      month = d[1];
      year = d[2];
    }
    if (year < 100) year += 2000;

    final t = time.split(_timeSep).map(int.parse).toList();
    var hour = t[0];
    final minute = t[1];
    final second = t.length > 2 ? t[2] : 0;
    if (ampm != null) {
      final pm = ampm.toLowerCase().startsWith('p');
      if (pm && hour < 12) hour += 12;
      if (!pm && hour == 12) hour = 0;
    }

    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (hour > 23 || minute > 59 || second > 59) return null;
    return DateTime(year, month, day, hour, minute, second);
  }
}
