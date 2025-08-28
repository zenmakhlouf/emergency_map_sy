
class UserProfile {
  final int id;
  final String name;
  final String phoneNumber;
  final String? profileImageUrl;

  const UserProfile({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.profileImageUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw const FormatException('Null JSON provided to UserProfile.fromJson');
    }

    final user = json['user'];
    if (user == null) {
      throw const FormatException('Missing "user" object in JSON');
    }

    return UserProfile(
      id: user['id'] ?? 0,
      name: user['name'] ?? 'No Name Provided',
      phoneNumber: user['auth_phone']?['phone_number'] ?? 'No Phone Number',
      profileImageUrl: user['profile_image'],
    );
  }
}
