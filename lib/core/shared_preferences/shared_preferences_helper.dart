import 'dart:ui';

import '../../features/auth/models/user_type.dart';
import 'shared_preferences_provider.dart';

class AppSharedPreferences {
  static SharedPreferencesProvider? sharedPreferencesProvider;

  static init() async {
    sharedPreferencesProvider = await SharedPreferencesProvider.getInstance();
  }

  //token
  static String get token => sharedPreferencesProvider!.read('token') ?? '';

  static saveToken(String value) => sharedPreferencesProvider!.save('token', value);

  static bool get hasToken => sharedPreferencesProvider!.contains('token');

  static removeToken() => sharedPreferencesProvider!.remove('token');

  // Locale
  static Locale? get locale => sharedPreferencesProvider!.read('locale') == null
      ? null
      : Locale(sharedPreferencesProvider!.read('locale')!);

  static saveLocale(Locale value) => sharedPreferencesProvider!.save('locale', value.languageCode);

  // User type
  static UserType? get userType =>
      UserType.fromString(sharedPreferencesProvider?.read('userType') ?? '');

  static void saveUserType(UserType userType) =>
      sharedPreferencesProvider?.save('userType', userType.name);
}
