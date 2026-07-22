import 'dart:io';

/// Utility script to compress assets/data/namtang_stops.json into assets/data/namtang_stops.json.gz
///
/// Usage:
///   dart run bin/compress_data.dart
void main() async {
  print('=== Bangkok Transit Data Asset Compressor (Dart CLI) ===');

  final jsonFile = File('assets/data/namtang_stops.json');
  if (!await jsonFile.exists()) {
    final gzFile = File('assets/data/namtang_stops.json.gz');
    if (await gzFile.exists()) {
      final gzSize = await gzFile.length();
      print('Found existing compressed asset: ${gzFile.path} ($gzSize bytes)');
      print(
        'To update, place your updated namtang_stops.json in assets/data/ and run:',
      );
      print('  dart run bin/compress_data.dart');
    } else {
      print('Error: ${jsonFile.path} not found.');
    }
    return;
  }

  final rawBytes = await jsonFile.readAsBytes();
  final originalSize = rawBytes.length;

  print(
    'Reading: ${jsonFile.path} (${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB)',
  );

  // Compress using built-in dart:io GZipCodec
  final compressedBytes = gzip.encode(rawBytes);
  final compressedSize = compressedBytes.length;

  final gzFile = File('assets/data/namtang_stops.json.gz');
  await gzFile.writeAsBytes(compressedBytes);

  final reduction = (1 - (compressedSize / originalSize)) * 100;

  print('Successfully generated: ${gzFile.path}');
  print(
    '  • Original Size:   $originalSize bytes (${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB)',
  );
  print(
    '  • Compressed Size: $compressedSize bytes (${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB)',
  );
  print('  • Savings:         ${reduction.toStringAsFixed(1)}% reduction');
  print('  • Original JSON preserved at: ${jsonFile.path}');
}
