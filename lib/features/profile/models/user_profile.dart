
import '../../chat/models/chat_models.dart';

class UserProfile {
  final int id;
  final String name;
  final String phoneNumber;
  final ProfileImage? profileImage;
  final List<String> roles;
  final AuthPhone? authPhone;
  final ResponderType? responderType;
  final LocationData? location;
  final List<ParticipationRequest> participationRequests;

  const UserProfile({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.profileImage,
    this.roles = const <String>[],
    this.authPhone,
    this.responderType,
    this.location,
    this.participationRequests = const <ParticipationRequest>[],
  });

  factory UserProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw const FormatException('Null JSON provided to UserProfile.fromJson');
    }

    final user = json['user'];
    if (user == null) {
      throw const FormatException('Missing "user" object in JSON');
    }

    // Use ChatUser.fromJson for consistent parsing
    final chatUser = ChatUser.fromJson(user);

    return UserProfile(
      id: chatUser.id,
      name: chatUser.name,
      phoneNumber: chatUser.authPhone?.phoneNumber ?? 'No Phone Number',
      profileImage: chatUser.profileImage,
      roles: chatUser.roles,
      authPhone: chatUser.authPhone,
      responderType: chatUser.responderType,
      location: chatUser.location,
      participationRequests: chatUser.participationRequests,
    );
  }

  // Helper getters for UI
  bool get isCitizen => roles.contains('citizen');
  bool get isResponder => roles.contains('responder');
  bool get isCoordinator => roles.contains('coordinator');
  bool get isAiAgent => roles.contains('ai-agent');
  
  String get primaryRole {
    if (isCoordinator) return 'Coordinator';
    if (isResponder) return 'Responder';
    if (isCitizen) return 'Citizen';
    if (isAiAgent) return 'AI Agent';
    return 'Unknown';
  }
  
  bool get hasLocation => location != null;
  bool get hasResponderSpecialization => responderType != null;
  int get pendingRequestsCount => participationRequests.where((r) => r.isPending).length;
}
