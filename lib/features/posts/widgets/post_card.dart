import 'package:emergency_map_sy/features/posts/screens/publish_post_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../widgets/custom_cached_image.dart';
import '../models/post.dart';

class PostCard extends StatelessWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(post.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 6,
      shadowColor: Colors.black26,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: post.images.isNotEmpty
                ? CustomCachedImage(
                    url: post.images.first.publicPath,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image_not_supported),
                    ),
                  )
                : Container(
                    width: 120,
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image, size: 40, color: Colors.grey),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          post.city?.name ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Chip(
                          label: Text(post.type?.name ?? ''),
                          backgroundColor: Colors.blue.shade50,
                          labelStyle: const TextStyle(
                            fontSize: 11,
                            color: Colors.blue,
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PublishPostScreen(post: post),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
