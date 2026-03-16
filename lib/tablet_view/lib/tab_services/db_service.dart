import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:print_helper/models/user_model.dart';
import 'package:print_helper/providers/lang_pro.dart';
import '../tab_utils/console_util.dart';

enum _UserKey { id, fname, lname, email, phone, image, token, tokenExpiry }

enum _RemMeKey { emailPhone, password, rememberMe }

class DbService {
  static const _storage = FlutterSecureStorage();

  static const String _intoKey = 'isOnboarded';
  static const String _deviceKey = 'deviceKey';
  static const String _langKey = 'langKey';

  static final _getUserKeys = _UserKey.values.map((e) => e.name).toList();
  static final _remMeKeys = _RemMeKey.values.map((e) => e.name).toList();

  //## onboarding status ##
  static Future<bool> isOnboarded() async =>
      (await _storage.read(key: _intoKey)) == 'true';

  static Future<void> markOnboardingComplete() async =>
      await _storage.write(key: _intoKey, value: 'true');

  //## device id status ##
  static Future<void> setDeviceId({required String deviceId}) async =>
      await _storage.write(key: _deviceKey, value: deviceId);

  static Future<String> getDeviceId() async =>
      await _storage.read(key: _deviceKey) ?? '';

  //## language status ##
  static Future<void> setLocale(Locales lang) async =>
      await _storage.write(key: _langKey, value: lang.name);

  static Future<Locales> getLocale() async =>
      fromString(await _storage.read(key: _langKey) ?? Locales.english.name);

  static Locales fromString(String lang) {
    switch (lang) {
      case 'english':
        return Locales.english;
      case 'arabic':
        return Locales.arabic;
      default:
        return Locales.english;
    }
  }

  //## User Data ##
  static Future<void> setUserData(User user) async {
    await _writeData({
      _UserKey.id.name: user.id,
      _UserKey.fname.name: user.fname,
      _UserKey.lname.name: user.lname,
      _UserKey.email.name: user.email,
      _UserKey.phone.name: user.phone,
      _UserKey.image.name: user.image,
      _UserKey.token.name: user.token,
      // _UserKey.tokenExpiry.name: user.tokenExpiry,
    });
  }

  static Future<User> getUserData() async {
    final userData = await _readData(_getUserKeys);

    return User(
      id: userData[0] ?? '',
      fname: userData[1] ?? '',
      lname: userData[2] ?? '',
      email: userData[3] ?? '',
      phone: userData[4] ?? '',
      image: userData[5] ?? '',
      token: userData[6] ?? '',
      // tokenExpiry: userData[7] ?? '',
    );
  }

  static Future<User> deleteUserData() async {
    await _deleteData(_getUserKeys);
    return User();
  }

  // ## Updated User Data ##
  static Future<User> updateUserData(UpdatedUser updatedUser) async {
    await _writeData({
      _UserKey.fname.name: updatedUser.fname,
      _UserKey.lname.name: updatedUser.lname,
      _UserKey.email.name: updatedUser.email,
      // TODO : phone number is not updatable as per client requirement
      // _UserKey.phone.name: updatedUser.phone,
      _UserKey.image.name: updatedUser.image,
    });

    return await getUserData();
  }

  // ## Check DB Change ##
  static Future<UpdatedUser?> checkDbChange(UpdatedUser updatedUser) async {
    final user = await getUserData();

    UpdatedUser data = UpdatedUser();
    bool hasChanges = false;

    final changes = {
      _UserKey.id: [updatedUser.id, user.id],
      _UserKey.fname: [updatedUser.fname, user.fname],
      _UserKey.lname: [updatedUser.lname, user.lname],
      _UserKey.email: [updatedUser.email, user.email],
      _UserKey.phone: [updatedUser.phone, user.phone],
      _UserKey.image: [updatedUser.image, user.image],
    };

    for (final entry in changes.entries) {
      final key = entry.key.name;
      final newValue = '${entry.value[0]}';
      final oldValue = '${entry.value[1]}';

      if (newValue != oldValue &&
          !(key == _UserKey.image.name && newValue == 'null')) {
        hasChanges = true;
        printData(title: '-->', data: 'Changed values of $key are');
        printData(title: 'Old: ', data: oldValue);
        printData(title: 'New: ', data: newValue);

        data = data.copyWith(
          fname: key == _UserKey.fname.name ? newValue : data.fname,
          lname: key == _UserKey.lname.name ? newValue : data.lname,
          email: key == _UserKey.email.name ? newValue : data.email,
          phone: key == _UserKey.phone.name ? newValue : data.phone,
          image: key == _UserKey.image.name ? newValue : data.image,
        );
      }
    }

    // Return null if no changes are detected
    return hasChanges ? data : null;
  }

  //## Remember Me ##
  static Future<void> setRemMe(
    String emailPhone,
    String pass,
    bool remMe,
  ) async {
    if (remMe) {
      await _writeData({
        _RemMeKey.emailPhone.name: emailPhone,
        _RemMeKey.password.name: pass,
        _RemMeKey.rememberMe.name: 'true',
      });
    } else {
      await deleteRemMe();
    }
  }

  static Future<List<String>> getRememberMe() async {
    final rData = await _readData(_remMeKeys);
    return [rData[0] ?? '', rData[1] ?? '', '${rData[2] == 'true'}'];
  }

  static Future<void> deleteRemMe() async => await _deleteData(_remMeKeys);

  //## Secure Storage Helpers ##
  static Future<void> _writeData(Map<String, String?> data) async {
    await Future.wait(
      data.entries.map((e) async {
        await _storage.write(key: e.key, value: e.value);
      }),
    );
  }

  static Future<List<String?>> _readData(List<String> keys) async =>
      await Future.wait(keys.map((key) => _storage.read(key: key)));

  static Future<void> _deleteData(List<String> keys) async {
    await Future.wait(keys.map((key) => _storage.delete(key: key)));
  }
}
