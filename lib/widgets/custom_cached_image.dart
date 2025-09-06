import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Utils
import 'shimmer_loader.dart';

class CustomCachedImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final bool isCircle;
  final double? width;
  final double? height;
  final double? radius;
  final Widget? errorBuilder;

  const CustomCachedImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.radius,
    this.errorBuilder,
    this.isCircle = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      fit: fit,
      imageBuilder: (
        context,
        imageProvider,
      ) =>
          isCircle
              ? CircleAvatar(
                  radius: radius ?? 35,
                  backgroundImage: imageProvider,
                  backgroundColor: Colors.grey.shade400,
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: imageProvider,
                      fit: fit,
                    ),
                  ),
                ),
      progressIndicatorBuilder: (
        context,
        url,
        progress,
      ) =>
          ClipRRect(
        borderRadius: BorderRadius.circular(isCircle ? 350 : 12),
        child: ShimmerLoader(
          child: isCircle
              ? CircleAvatar(
                  radius: radius ?? 35,
                  backgroundColor: Colors.grey.shade100,
                )
              : Container(
                  color: Colors.grey.shade100,
                ),
        ),
      ),
      errorWidget: (
        context,
        url,
        error,
      ) =>
          errorBuilder ??
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.image_outlined),
          ),
    );
  }
}
