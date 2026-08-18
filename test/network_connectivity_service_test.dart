import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sing_list/lyrics/network_connectivity_service.dart';

void main() {
  test('any HTTP response confirms basic internet access', () async {
    final service = NetworkConnectivityService(
      httpClient: MockClient((_) async => http.Response('busy', 503)),
    );

    await expectLater(service.checkInternetAccess(), completes);
  });

  test('internet check has a short timeout with a clear error', () async {
    final service = NetworkConnectivityService(
      httpClient: MockClient((_) async {
        await Completer<void>().future;
        return http.Response('', 200);
      }),
    );

    await expectLater(
      service.checkInternetAccess(timeout: Duration.zero),
      throwsA(
        isA<NetworkConnectivityException>().having(
          (error) => error.message,
          'message',
          contains('超时'),
        ),
      ),
    );
  });
}
