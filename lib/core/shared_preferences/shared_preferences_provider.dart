import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesProvider {
  static SharedPreferences? sharedPreferences;

  static SharedPreferencesProvider? sharedPreferencesProvider;
  static Future<SharedPreferencesProvider> getInstance() async {
    if (sharedPreferencesProvider == null) {
      sharedPreferences = await SharedPreferences.getInstance();
      return sharedPreferencesProvider = SharedPreferencesProvider();
    }
    return sharedPreferencesProvider!;
  }

  init() async {
    sharedPreferences = await SharedPreferences.getInstance();
  }

  String? read(String key) {
    return contains(key) ? json.decode(sharedPreferences?.getString(key) ??'') : null;
  }

  bool readBool(String key) {
    return contains(key) ? sharedPreferences?.getBool(key) ?? false : false;
  }



 void save(String key,String value) {
    sharedPreferences!.setString(key, json.encode(value));
  }


 void saveBool(String key, bool value){
   sharedPreferences!.setBool(key, value);
 }

  contains(String key) {
    return sharedPreferences!.containsKey(key);
  }

  remove(String key) {
    sharedPreferences!.remove(key);
  }

  clear() {
    sharedPreferences!.clear();
  }
}
