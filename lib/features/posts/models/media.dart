class Media {
  final int id;
  final String publicPath;

  const Media({required this.id, required this.publicPath});

  factory Media.fromJson(Map<String, dynamic> json) => Media(
        id: json['id'],
        publicPath: json['public_path'],
      );
}
