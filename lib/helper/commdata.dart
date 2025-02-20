import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info/package_info.dart';

class CommData {
  static const String _spKeyCustomServerURL = 'custom_server_url';
  static const String _spKeyProxy = 'proxy';
  static const String _spKeyDevMode = 'dev_mode';
  static const String _spKeyTestNet = 'test_net_flag';

  static bool useZProtocol = true;
  static bool useZJsonEncodeOnPostBody = true;
  static bool easyLoadingLoaded = false;

  static late SharedPreferences _sp;
  static late PackageInfo _pi;

  static String _customServerURL = '';
  static bool _devMode = true;
  static String _proxy = '';
  static String _version = '';
  static String _udid = '';
  static int _testnetFlag = 0; // 0:正式网; 1:测网testnet; 2:回归测试网(regtest)

  static Future<void> init() async {
    spInit(await SharedPreferences.getInstance());
    piInit(await PackageInfo.fromPlatform());
    _udid = await FlutterUdid.udid;
  }

  static void spInit(SharedPreferences sp) {
    _sp = sp;

    _customServerURL = _sp.getString(_spKeyCustomServerURL) ?? '';
    _proxy = _sp.getString(_spKeyProxy) ?? '';
    _devMode = _sp.getBool(_spKeyDevMode) ?? false;
    _testnetFlag = _sp.getInt(_spKeyTestNet) ?? 0;
  }

  static SharedPreferences get sp {
    return _sp;
  }

  static void piInit(PackageInfo pi) {
    _pi = pi;

    _version = pi.version;
  }

  static PackageInfo get pi {
    return _pi;
  }

  static bool get devMode {
    return _devMode;
  }

  static set devMode(bool v) {
    _devMode = v;

    _sp.setBool(_spKeyDevMode, v);
  }

  static int get testnetFlag {
    return _testnetFlag;
  }

  static set testnetFlag(int v) {
    _testnetFlag = v;

    _sp.setInt(_spKeyTestNet, v);
  }

  static String get customServerURL {
    return _customServerURL;
  }

  static set customServerURL(String v) {
    _customServerURL = v;

    _sp.setString(_spKeyCustomServerURL, v);
  }

  static String get proxy {
    return _proxy;
  }

  static set proxy(String v) {
    _proxy = v;

    _sp.setString(_spKeyProxy, v);
  }

  static String get version {
    return _version;
  }

  static String get udid {
    return _udid;
  }

  static String getTokenStorageKey() {
    if (_customServerURL != '') {
      return 'token_custom';
    }

    if (devMode) {
      return 'token_on_dev';
    }

    return 'token';
  }

  static String? get token {
    return _sp.getString(getTokenStorageKey());
  }

  static set token(String? s) {
    if (s == null) {
      _sp.remove(getTokenStorageKey());
    } else {
      _sp.setString(getTokenStorageKey(), s);
    }
  }

  static String getServerURL() {
    if (_customServerURL != '') {
      return _customServerURL;
    }

    if (testnetFlag == 1) {
      return devMode
          ? dotenv.env['SERVER_DOMAIN_DEV_TESTNET']!
          : dotenv.env['SERVER_DOMAIN_TESTNET']!;
    }

    if (testnetFlag == 2) {
      return devMode
          ? dotenv.env['SERVER_DOMAIN_DEV_REGTEST']!
          : dotenv.env['SERVER_DOMAIN_REGTEST']!;
    }

    return devMode
        ? dotenv.env['SERVER_DOMAIN_DEV']!
        : dotenv.env['SERVER_DOMAIN']!;
  }
}
