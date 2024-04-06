import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;

class NetUtils {
  static String? token;
  static bool devMode = true;

  /// http request methods
  static const String getMethod = 'get';
  static const String postMethod = 'post';

  static reset(String? newToken) {
    token = newToken;
  }

  static Uri getUri(String url, Map<String, dynamic>? parameters) {
    String baseUrl = devMode
        ? dotenv.env['SERVER_DOMAIN_DEV']!
        : dotenv.env['SERVER_DOMAIN']!;
    return baseUrl.startsWith('https://')
        ? Uri.https(
            baseUrl.substring(baseUrl.indexOf("://") + 3), url, parameters)
        : Uri.http(
            baseUrl.substring(baseUrl.indexOf("://") + 3), url, parameters);
  }

  ///Get请求
  static void getHttp<T>(
    String url, {
    Map<String, dynamic>? parameters,
    Function(T)? onSuccess,
    Function(int code, String msg, T resp)? onResult,
    Function(String error)? onError,
    Function()? onReLogin,
  }) async {
    try {
      EasyLoading.show(status: '加载中...', dismissOnTap: false);

      final response = await http.get(
        getUri(url, parameters),
        headers: {
          'Accept': 'application/json,*/*',
          'Content-Type': 'application/json',
          'token': token ?? "",
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        Map<String, dynamic> resp =
            json.decode(utf8.decode(response.bodyBytes));

        var code = resp['code'];
        if (code < 100) {
          if (onSuccess != null && resp['code'] == 0) {
            onSuccess(resp['resp']);
          } else {
            throw Exception('erroMsg:${resp['message']}');
          }

          if (onResult != null) {
            onResult(resp['code'], resp['message'] as String, resp['resp']);
          }
        } else {
          if (code == 106 || code == 107) {
            // CodeInvalidToken CodeNeedAuth
            if (onReLogin != null) {
              onReLogin();

              return;
            }
          }
          throw Exception('erroMsg:${resp['message']}');
        }
      } else {
        if (onError != null) {
          onError('${response.statusCode}');
        }
      }
    } catch (e) {
      if (onError != null) {
        onError(e.toString());
      }
    } finally {
      EasyLoading.dismiss();
    }
  }

  static void postHttp<T>(
    String url, {
    Map<String, dynamic>? parameters,
    Object? data,
    Function(T)? onSuccess,
    Function(int code, String msg, T resp)? onResult,
    Function(String error)? onError,
    Function()? onReLogin,
  }) async {
    try {
      EasyLoading.show(status: '加载中...', dismissOnTap: false);

      final response = await http
          .post(getUri(url, parameters),
              headers: {
                'Accept': 'application/json,*/*',
                'Content-Type': 'application/json',
                'token': token ?? "",
              },
              body: jsonEncode(data))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        Map<String, dynamic> resp =
            json.decode(utf8.decode(response.bodyBytes));

        var code = resp['code'];
        if (code < 100) {
          if (onSuccess != null && resp['code'] == 0) {
            onSuccess(resp['resp']);
          } else {
            throw Exception('${resp['message']}');
          }

          if (onResult != null) {
            onResult(resp['code'], resp['message'] as String, resp['resp']);
          }
        } else {
          if (code == 106 || code == 107) {
            // CodeInvalidToken CodeNeedAuth
            if (onReLogin != null) {
              onReLogin();

              return;
            }
          }

          throw Exception('${resp['message']}');
        }
      } else {
        if (onError != null) {
          onError('${response.statusCode}');
        }
      }
    } catch (e) {
      if (onError != null) {
        onError(e.toString());
      }
    } finally {
      EasyLoading.dismiss();
    }
  }

  static void requestHttp<T>(
    String url, {
    Map<String, dynamic>? parameters,
    Object? data,
    method,
    Function(dynamic)? onSuccess,
    Function(int code, String msg, dynamic resp)? onResult,
    Function(String error)? onError,
    Function()? onReLogin,
  }) async {
    parameters = parameters ?? {};
    method = method ?? 'GET';

    if (method == NetUtils.getMethod) {
      getHttp(url, parameters: parameters, onSuccess: (data) {
        if (onSuccess != null) {
          onSuccess(data);
        }
      }, onResult: (code, msg, data) {
        if (onResult != null) {
          onResult(code, msg, data);
        }
      }, onError: (error) {
        if (onError != null) {
          if (error.startsWith('Exception:')) {
            error = error.substring('Exception:'.length);
          }
          onError(error);
        }
      }, onReLogin: () {
        if (onReLogin != null) {
          onReLogin();
        }
      });
    } else if (method == NetUtils.postMethod) {
      postHttp(url, parameters: parameters, data: data, onSuccess: (data) {
        if (onSuccess != null) {
          onSuccess(data);
        }
      }, onResult: (code, msg, data) {
        if (onResult != null) {
          onResult(code, msg, data);
        }
      }, onError: (error) {
        if (onError != null) {
          if (error.startsWith('Exception:')) {
            error = error.substring('Exception:'.length);
          }
          onError(error);
        }
      }, onReLogin: () {
        if (onReLogin != null) {
          onReLogin();
        }
      });
    }
  }
}
