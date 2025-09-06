class CivilEmergencyTypes {
  final int id;
  final String name;
  final String description;

  const CivilEmergencyTypes({
    required this.id,
    required this.name,
    required this.description,
  });

  factory CivilEmergencyTypes.fromJson(Map<String, dynamic> json) => CivilEmergencyTypes(
        id: json['id'],
        name: json['name'],
        description: json['description'],
      );
}
