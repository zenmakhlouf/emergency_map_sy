enum UserType {
  citizen,
  responder,
  coordinator;

  factory UserType.fromString(String userType) {
    switch (userType) {
      case 'coordinator':
        return UserType.coordinator;
      case 'responder':
        return UserType.responder;
      default:
        return UserType.citizen;
    }
  }
}
