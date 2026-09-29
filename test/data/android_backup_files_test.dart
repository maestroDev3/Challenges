import 'package:challenges/data/android_backup_files.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ritual/backup_files');
  final calls = <MethodCall>[];
  Object? reply;

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply;
    });
  });

  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  group('AndroidBackupFiles', () {
    test('save übergibt Name, MIME-Typ und Inhalt', () async {
      reply = true;
      final ok = await const AndroidBackupFiles().save(
          name: 'ritual-backup-2026-09-29.json',
          mimeType: 'application/json',
          content: '{"a":1}');
      expect(ok, isTrue);
      expect(calls.single.method, 'save');
      expect(calls.single.arguments, {
        'name': 'ritual-backup-2026-09-29.json',
        'mimeType': 'application/json',
        'content': '{"a":1}',
      });
    });

    test('Abbruch beim Speichern liefert false', () async {
      reply = false;
      expect(
          await const AndroidBackupFiles()
              .save(name: 'x.csv', mimeType: 'text/csv', content: ''),
          isFalse);
      reply = null;
      expect(
          await const AndroidBackupFiles()
              .save(name: 'x.csv', mimeType: 'text/csv', content: ''),
          isFalse);
    });

    test('open liefert den Dateiinhalt, bei Abbruch null', () async {
      reply = '{"format":"ritual-backup"}';
      expect(await const AndroidBackupFiles().open(),
          '{"format":"ritual-backup"}');
      expect(calls.single.method, 'open');
      reply = null;
      expect(await const AndroidBackupFiles().open(), isNull);
    });
  });
}
