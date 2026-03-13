import 'package:dataviewer/core/networking/tomcat_session_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;
  late SharedPreferencesTomcatSessionStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
    store = SharedPreferencesTomcatSessionStore(preferences);
  });

  test('stores JSESSIONID from response cookies', () {
    store.captureFromResponse(
      Response<void>(
        requestOptions: RequestOptions(path: '/api/v1/channels/search'),
        headers: Headers.fromMap(<String, List<String>>{
          'set-cookie': <String>[
            'other=value; Path=/',
            'JSESSIONID=session-123; Path=/dataviewer; HttpOnly',
          ],
        }),
      ),
    );

    expect(
      preferences.getString('dataviewer.tomcat.jsessionid.v1'),
      'session-123',
    );
  });

  test('adds persisted JSESSIONID to outgoing requests', () async {
    await preferences.setString('dataviewer.tomcat.jsessionid.v1', 'session-9');
    final request = RequestOptions(path: '/api/v1/plots/query');

    store.applyToRequest(request);

    expect(request.headers['cookie'], 'JSESSIONID=session-9');
  });

  test('replaces stale JSESSIONID while preserving other cookies', () async {
    await preferences.setString('dataviewer.tomcat.jsessionid.v1', 'fresh-id');
    final request = RequestOptions(
      path: '/api/v1/plots/live',
      headers: <String, Object>{
        'cookie': 'theme=dark; JSESSIONID=stale-id',
      },
    );

    store.applyToRequest(request);

    expect(request.headers['cookie'], 'theme=dark; JSESSIONID=fresh-id');
  });
}
