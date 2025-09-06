import 'package:image_picker/image_picker.dart';

import 'file_compressor.dart';

Future<List<XFile>> pickAndCompressImages({
  bool allowMultiple = false,
  int maxWidth = 1920,
  int maxHeight = 1080,
  int quality = 25,
  ImageSource source = ImageSource.gallery,
}) async {
  final picker = ImagePicker();
  final List<XFile> pickedFiles;

  if (source == ImageSource.gallery && allowMultiple) {
    final images = await picker.pickMultiImage();
    pickedFiles = images;
  } else {
    final XFile? file = await picker.pickImage(source: source);
    pickedFiles = file != null ? [file] : [];
  }

  final List<XFile> result = [];

  for (final file in pickedFiles) {
    try {
      final compressedFile = await fileCompressor(
        file,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      );

      result.add(compressedFile);
    } catch (e) {
      print(e);
      result.add(file);
    }
  }

  return result;
}