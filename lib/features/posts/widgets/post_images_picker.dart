import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../global_functions/image_uploader.dart';
import '../../../utils/urls.dart';
import '../../../widgets/custom_cached_image.dart';
import '../cubit/posts_cubit.dart';

class PostImagesPicker extends StatelessWidget {
  final PostsCubit cubit;

  const PostImagesPicker({super.key, required this.cubit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
         'images',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...cubit.existingImages.map(
              (media) => Stack(
                children: [
                  CustomCachedImage(
                    width: 80,
                    height: 80,
                    url: media.publicPath,
                  ),
                  Positioned(
                    top: -10,
                    right: -10,
                    child: IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => cubit.removeExistingImage(media),
                    ),
                  ),
                ],
              ),
            ),
            ...cubit.selectedImages.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final file = entry.value;
                return Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(file),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -10,
                      right: -10,
                      child: IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => cubit.removeImage(index),
                      ),
                    ),
                  ],
                );
              },
            ),
            GestureDetector(
              onTap: () => _pickImages(context),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_photo_alternate,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _pickImages(BuildContext context) async {
    final List<XFile>? pickedFiles = await showModalBottomSheet<List<XFile>>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('Gallery'),
              onTap: () async {
                final files = await pickAndCompressImages(allowMultiple: true);
                Navigator.pop(context, files);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('Camera'),
              onTap: () async {
                final files = await pickAndCompressImages(
                  allowMultiple: false,
                  source: ImageSource.camera,
                );
                Navigator.pop(context, files);
              },
            ),
          ],
        ),
      ),
    );

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      final files = pickedFiles.map((file) => File(file.path)).toList();
      cubit.addImages(files);
    }
  }
}
