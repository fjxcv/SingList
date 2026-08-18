import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class NetworkConnectivityException implements Exception {
  const NetworkConnectivityException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NetworkConnectivityService {
  NetworkConnectivityService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<void> checkInternetAccess({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      // 收到任意 HTTP 响应都说明 DNS、代理和基础互联网链路可用；
      // 歌词服务本身是否健康由后续独立检查判断。
      await _httpClient.get(
        Uri.parse('https://lrclib.net/'),
        headers: const {
          'User-Agent': 'SingList/0.1.6 (https://github.com/fjxcv/SingList)',
        },
      ).timeout(timeout);
    } on TimeoutException {
      throw const NetworkConnectivityException(
        '网络连接检查超时，请检查网络、代理或稍后重试',
      );
    } on SocketException {
      throw const NetworkConnectivityException(
        '当前无法访问互联网，请检查网络、DNS 或代理设置',
      );
    } on http.ClientException {
      throw const NetworkConnectivityException(
        '网络请求失败，请检查网络或代理设置',
      );
    }
  }
}
