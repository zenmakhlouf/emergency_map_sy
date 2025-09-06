import 'package:emergency_map_sy/features/posts/models/city.dart';
import 'package:emergency_map_sy/features/posts/models/civil_emergency_types.dart';

import 'media.dart';

class Post {
  final int id;
  final String title;
  final String description;
  final CivilEmergencyTypes? type;
  final City? city;
  final List<Media> images;
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.city,
    required this.type,
    required this.title,
    required this.description,
    this.images = const [],
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['civil_emergency_type'] == null
          ? null
          : CivilEmergencyTypes.fromJson(json['civil_emergency_type']),
      city: json['city'] == null ? null : City.fromJson(json['city']),
      images: json['images'] == null
          ? []
          : List<Media>.from(
              json['images'].map(
                    (e) => Media.fromJson(e),
                  ) ??
                  [],
            ),
      createdAt: DateTime.tryParse(json['created_at']) ?? DateTime.now(),
    );
  }
}
