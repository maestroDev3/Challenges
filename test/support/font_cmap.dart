import 'dart:io';
import 'dart:typed_data';

/// Liest die Unicode-Zeichen einer TrueType-Datei aus der `cmap`-Tabelle
/// (Format 4 und 12), damit Tests prüfen können, welche Schriftzeichen eine
/// eingebundene Schrift wirklich enthält.
Set<int> fontCodePoints(String path) {
  final data = ByteData.sublistView(File(path).readAsBytesSync());
  final tables = data.getUint16(4);
  int? cmap;
  for (var i = 0; i < tables; i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes(
        [for (var j = 0; j < 4; j++) data.getUint8(record + j)]);
    if (tag == 'cmap') cmap = data.getUint32(record + 8);
  }
  if (cmap == null) throw FormatException('keine cmap-Tabelle', path);

  final result = <int>{};
  final subtables = data.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final offset = cmap + data.getUint32(cmap + 4 + i * 8 + 4);
    switch (data.getUint16(offset)) {
      case 4:
        final segments = data.getUint16(offset + 6) ~/ 2;
        final ends = offset + 14;
        final starts = ends + segments * 2 + 2;
        for (var s = 0; s < segments; s++) {
          final start = data.getUint16(starts + s * 2);
          final end = data.getUint16(ends + s * 2);
          if (start == 0xFFFF) continue;
          for (var c = start; c <= end; c++) {
            result.add(c);
          }
        }
      case 12:
        final groups = data.getUint32(offset + 12);
        for (var g = 0; g < groups; g++) {
          final group = offset + 16 + g * 12;
          for (var c = data.getUint32(group);
              c <= data.getUint32(group + 4);
              c++) {
            result.add(c);
          }
        }
    }
  }
  return result;
}
