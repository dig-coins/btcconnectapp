import 'dart:convert';
import 'dart:developer';
import 'package:btcconnectapp/helper/commdata.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'dart:io';

typedef HTTPRequestGenerator = Future<HttpClientRequest> Function(
    HttpClient client, Uri url);

typedef HTTPRequestModifier = Function(HttpClientRequest request);

class NetOpResult {
  bool reLoginFlag;
  bool is204;
  int code;
  String msg;
  dynamic resp;

  NetOpResult(
      {this.reLoginFlag = false,
      this.is204 = false,
      this.code = -100,
      this.msg = '',
      this.resp});
}

class NetUtils {
  /// http request methods
  static const String getMethod = 'get';
  static const String postMethod = 'post';

  static HTTPRequestModifier requestModifier =
      (HttpClientRequest request) => {};

  static setHTTPRequestModifier(HTTPRequestModifier modifier) {
    requestModifier = modifier;
  }

  static Uri getUri(String url, Map<String, dynamic>? parameters) {
    Map<String, dynamic> allParameters = {};
    if (parameters != null && parameters.isNotEmpty) {
      allParameters.addAll(parameters);
    }

    final splitted = url.split('?');
    if (splitted.length == 2) {
      url = splitted[0];
      final queries = splitted[1].split('&');
      for (int i = 0; i < queries.length; i++) {
        final qs = queries[i].split('=');
        if (qs.length == 2) {
          allParameters[qs[0]] = qs[1];
        }
      }
    }

    if (allParameters.isNotEmpty) {
      parameters = allParameters;
    } else {
      parameters = null;
    }

    String baseUrl = CommData.getServerURL();
    baseUrl = baseUrl.toLowerCase();
    if (!url.startsWith('/')) {
      url = '/$url';
    }

    var index = baseUrl.indexOf('://');
    if (index != -1) {
      String s = baseUrl.substring(baseUrl.indexOf("://") + 3);
      var index2 = s.indexOf('/');
      if (index2 != -1) {
        s = s.substring(index2);
        if (s.endsWith('/')) {
          s = s.substring(0, s.length - 1);
        }

        url = s + url;
        baseUrl = baseUrl.substring(0, index2 + index + 3);
      }
    }

    var s = baseUrl.startsWith('https://')
        ? Uri.https(
            baseUrl.substring(baseUrl.indexOf("://") + 3), url, parameters)
        : Uri.http(
            baseUrl.substring(baseUrl.indexOf("://") + 3), url, parameters);

    log(s.toString());
    return s;
  }

  static Future<NetOpResult> _doHttp<T>(
    String url,
    Map<String, dynamic>? parameters,
    HTTPRequestGenerator requestGenerator, {
    Map<String, Object>? headers,
    Object? data,
    bool? background,
    Duration? timeout,
  }) async {
    bool easyLoading = false;

    try {
      if (background == null || !background) {
        if (CommData.easyLoadingLoaded) {
          EasyLoading.show(status: '加载中...', dismissOnTap: false);
          easyLoading = true;
        }
      }

      final client = HttpClient();

      String proxy = CommData.proxy;
      if (proxy != '') {
        client.findProxy = (url) {
          return 'PROXY $proxy';
        };
      }

      HttpClientRequest request =
          await requestGenerator(client, getUri(url, parameters));

      request.headers.add('Accept', 'application/json,*/*');
      request.headers.add('Content-Type', 'application/json');
      request.headers.add('Authorization', 'Basic ${CommData.token}');
      request.headers.add('U-Did', CommData.udid);
      headers?.forEach((k, v) {
        request.headers.set(k, v);
      });
      requestModifier(request);

      if (data != null) {
        if (CommData.useZJsonEncodeOnPostBody) {
          request.add(utf8.encode(jsonEncode(data)));
        } else {
          request.add(utf8.encode(data.toString()));
        }
      }

      timeout ??= const Duration(seconds: 30);

      HttpClientResponse response = await request.close().timeout(timeout);

      if (response.statusCode == 204) {
        return Future.value(NetOpResult(is204: true, code: 0, msg: '204'));
      }

      if (response.statusCode == 401) {
        return Future.value(NetOpResult(
            code: 0, reLoginFlag: true, msg: 'Authorization Required'));
      }

      if (response.statusCode == 200) {
        Map<String, dynamic> resp =
            json.decode(await response.transform(utf8.decoder).join());

        if (!CommData.useZProtocol) {
          return Future.value(NetOpResult(code: 0, resp: resp));
        }

        var code = resp['code'];
        if (code == 13 || code == 6) {
          // CodeErrInvalidToken CodeErrNeedAuth
          return Future.value(NetOpResult(
              code: resp['code'],
              msg: resp['message'] ?? 'Authorization Required',
              resp: resp['resp'],
              reLoginFlag: true));
        }

        return Future.value(NetOpResult(
            code: resp['code'], msg: resp['message'], resp: resp['resp']));
      }

      return Future.value(
          NetOpResult(code: -1, msg: 'status code is ${response.statusCode}'));
    } catch (e) {
      return Future.value(NetOpResult(code: -1, msg: e.toString()));
    } finally {
      if (easyLoading) {
        EasyLoading.dismiss();
      }
    }
  }

  static Future<NetOpResult> getHttp<T>(
    String url, {
    Map<String, dynamic>? parameters,
    Map<String, Object>? headers,
    bool? background,
    Duration? timeout,
  }) async {
    Duration t = timeout ??= const Duration(seconds: 30);
    return await _doHttp(url, parameters, (HttpClient client, Uri url) {
      return client.getUrl(url).timeout(t);
    }, background: background, timeout: timeout);
  }

  static Future<NetOpResult> postHttp<RESP>(
    String url, {
    Map<String, dynamic>? parameters,
    Map<String, Object>? headers,
    Object? data,
    bool? background,
    Duration? timeout,
  }) async {
    Duration t = timeout ??= const Duration(seconds: 30);
    return await _doHttp(url, parameters, (HttpClient client, Uri url) {
      return client.postUrl(url).timeout(t);
    }, data: data, background: background, timeout: timeout);
  }

  static Future<NetOpResult> requestHttp<T>(
    String url, {
    Map<String, dynamic>? parameters,
    Map<String, Object>? headers,
    Object? data,
    bool? background,
    String? method,
    Duration? timeout,
  }) async {
    parameters = parameters ?? {};
    method = method ?? 'GET';

    if (method.toLowerCase() == NetUtils.getMethod.toLowerCase() ||
        method == '') {
      return await getHttp(url,
          parameters: parameters,
          headers: headers,
          background: background,
          timeout: timeout);
    } else if (method.toLowerCase() == NetUtils.postMethod.toLowerCase()) {
      return await postHttp(url,
          parameters: parameters,
          data: data,
          headers: headers,
          background: background,
          timeout: timeout);
    } else {
      return Future.value(NetOpResult(code: -2));
    }
  }
}
