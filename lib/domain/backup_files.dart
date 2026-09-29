/// Datei-Dialog des Systems zum Speichern und Öffnen von Backups, damit der
/// Nutzer den Ort (Downloads, Google Drive, …) selbst wählt.
abstract interface class BackupFiles {
  /// Speichert [content] unter einem vom Nutzer gewählten Ort; `false`, wenn
  /// er den Dialog abbricht.
  Future<bool> save({
    required String name,
    required String mimeType,
    required String content,
  });

  /// Liest eine vom Nutzer gewählte Datei; `null`, wenn er abbricht.
  Future<String?> open();
}
