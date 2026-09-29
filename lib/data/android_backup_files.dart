import 'package:flutter/services.dart';

import '../domain/backup_files.dart';

/// Android-Dateiauswahl (Storage Access Framework) über `MainActivity.kt` –
/// ohne Speicher-Berechtigung und ohne zusätzliches Paket.
class AndroidBackupFiles implements BackupFiles {
  const AndroidBackupFiles();

  static const _channel = MethodChannel('ritual/backup_files');

  @override
  Future<bool> save({
    required String name,
    required String mimeType,
    required String content,
  }) async =>
      await _channel.invokeMethod<bool>('save', {
        'name': name,
        'mimeType': mimeType,
        'content': content,
      }) ??
      false;

  @override
  Future<String?> open() => _channel.invokeMethod<String>('open');
}
