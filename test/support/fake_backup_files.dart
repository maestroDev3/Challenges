import 'package:challenges/domain/backup_files.dart';

/// Datei-Dialog ohne System: merkt sich Gespeichertes, liefert [toOpen].
class FakeBackupFiles implements BackupFiles {
  FakeBackupFiles({this.toOpen, this.cancelSave = false});

  String? toOpen;
  bool cancelSave;
  final saved = <({String name, String mimeType, String content})>[];

  @override
  Future<bool> save({
    required String name,
    required String mimeType,
    required String content,
  }) async {
    if (cancelSave) return false;
    saved.add((name: name, mimeType: mimeType, content: content));
    return true;
  }

  @override
  Future<String?> open() async => toOpen;
}
