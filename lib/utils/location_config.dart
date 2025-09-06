/// Configuration class for location services
class LocationConfig {
  /// Disable all location polling for responders and focus mode
  /// Set this to true to completely disable location polling for responders
  /// This is useful when backend doesn't support responder location viewing
  static const bool disableResponderLocationPolling = false;
  
  /// Disable users location polling (viewing other users)
  /// This affects the ability to see other users on the map
  static const bool disableUsersLocationPolling = false;
  
  /// Disable own location polling (sending location to backend)
  /// This affects sending the current user's location to the server
  static const bool disableOwnLocationPolling = false;
}