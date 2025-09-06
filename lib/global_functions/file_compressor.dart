import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';

Future<XFile> fileCompressor(
    XFile file, {
      required int maxWidth,
      required int maxHeight,
      required int quality,
    }) async {
  final originalFile = File(file.path);

  // Validate original file exists
  if (!await originalFile.exists()) {
    print('Original file not found: ${file.path}');
    return file;
  }

  // Create valid target path
  final targetPath = path.join(
    path.dirname(file.path),
    'compressed_${path.basename(file.path)}',
  );

  // Compress image with proper constraints
  final compressedXFile = await FlutterImageCompress.compressAndGetFile(
    file.path,
    targetPath,
    quality: quality,
    minWidth: maxWidth,
    minHeight: maxHeight,
  );

  // Handle compression failure
  if (compressedXFile == null) {
    print('Compression failed! Returning original file.');
    return file;
  }

  return compressedXFile;
}