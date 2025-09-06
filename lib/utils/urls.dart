class Urls {
  static const url = 'https://help-map.saadalabyad.com';

  // BaseUrls
  static const baseUrl = '$url/api/v1';
  static const storageUrl = '$url/storage';

  static const sendOTP = '$baseUrl/auth/send-otp';
  static const checkOTP = '$baseUrl/auth/check-otp';
  static const login = '$baseUrl/auth/login';
  static const register = '$baseUrl/auth/register';
  static const reports = '$baseUrl/reports';
  static const chats = '$baseUrl/chats';
  static const profile = '$baseUrl/profile';
  static String chatMessages(int chatId) => '$baseUrl/chats/$chatId/messages';
  static String sendChatMessage(int chatId) =>
      '$baseUrl/chats/$chatId/messages';
  static const newChatMessage = '$baseUrl/chats/new/messages';

  static const cities = '$baseUrl/cities';
  static const civilEmergencies = '$baseUrl/civil-emergencies';
  static const civilEmergencyTypes = '$baseUrl/civil-emergency-types';
}
