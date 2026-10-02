import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
const jsonMime = 'application/json';

/// File yang sudah dibuat dan siap disimpan / dibagikan.
class OutputFile {
  final String name;
  final Uint8List bytes;
  final String path; // lokasi sementara (dipakai untuk Share)
  final String mime;
  const OutputFile(
      {required this.name,
      required this.bytes,
      required this.path,
      required this.mime});
}

class FileOutput {
  /// Menulis file ke folder sementara aplikasi.
  static Future<OutputFile> prepare(
      String name, List<int> bytes, String mime) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return OutputFile(
        name: name,
        bytes: Uint8List.fromList(bytes),
        path: file.path,
        mime: mime);
  }

  /// Membuka dialog "Simpan sebagai" bawaan Android (pilih folder sendiri, mis. Downloads).
  /// Mengembalikan false jika dibatalkan.
  static Future<bool> saveToDevice(OutputFile f) async {
    final result = await FilePicker.saveFile(
      dialogTitle: 'Simpan file',
      fileName: f.name,
      bytes: f.bytes,
    );
    return result != null;
  }

  /// Membuka menu Share (Drive, WhatsApp, email, dll). false jika ditutup tanpa memilih.
  static Future<bool> share(OutputFile f) async {
    final result = await SharePlus.instance.share(
      ShareParams(
          files: [XFile(f.path, mimeType: f.mime, name: f.name)],
          subject: f.name),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}
