# chat_rank

Flutter app (Android + iOS) that turns WhatsApp chat exports into a contact leaderboard and dashboard.

## Status

Done (untested, written without a Dart toolchain):
- `lib/parser/whatsapp_parser.dart`: Android and iOS export formats, 12h/24h, day-first/month-first detection
- `lib/metrics/metrics_engine.dart`: sent vs received, median response times (12h cap)
- `lib/metrics/leaderboard.dart`: weighted ranking (volume 0.5, balance 0.2, speed 0.3)
- `test/parser_and_metrics_test.dart`

## First run

```bash
cd chat_rank
flutter create . --platforms=android   # generates android/ around the existing lib/ and pubspec (iOS comes later)
flutter test
```

## Next

1. SQLite storage (drift or sqflite) with dedupe on `ChatMessage.dedupeKey`
2. "Which participant are you?" picker, remembered per account
3. Share target: Android intent filter, iOS Share Extension (receive_sharing_intent)
4. Dashboard and leaderboard UI (fl_chart)
5. Re-export reminders (flutter_local_notifications)
