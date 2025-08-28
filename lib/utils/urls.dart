class Urls {
  static const baseUrl = 'https://help-map.saadalabyad.com/api/v1';

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
}
