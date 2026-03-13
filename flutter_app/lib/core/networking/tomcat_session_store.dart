import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class TomcatSessionStore {
  void applyToRequest(RequestOptions options);

  void captureFromResponse(Response<dynamic>? response);
}

class SharedPreferencesTomcatSessionStore implements TomcatSessionStore {
  SharedPreferencesTomcatSessionStore(this._preferences);

  static const String _storageKey = 'dataviewer.tomcat.jsessionid.v1';
  static const String _cookieHeaderName = 'cookie';
  static const String _setCookieHeaderName = 'set-cookie';
  static const String _sessionCookieName = 'JSESSIONID';

  final SharedPreferences _preferences;

  @override
  void applyToRequest(RequestOptions options) {
    final sessionId = _preferences.getString(_storageKey);
    if (sessionId == null || sessionId.trim().isEmpty) {
      return;
    }

    final sessionCookie = '$_sessionCookieName=$sessionId';
    final existingHeader = _asCookieHeader(options.headers[_cookieHeaderName]);
    options.headers[_cookieHeaderName] = existingHeader == null
        ? sessionCookie
        : _mergeCookieHeader(existingHeader, sessionCookie);
  }

  @override
  void captureFromResponse(Response<dynamic>? response) {
    if (response == null) {
      return;
    }

    final setCookieValues = response.headers.map[_setCookieHeaderName];
    if (setCookieValues == null) {
      return;
    }

    for (final rawCookie in setCookieValues) {
      final sessionId = _extractSessionId(rawCookie);
      if (sessionId == null) {
        continue;
      }
      if (sessionId.isEmpty) {
        _preferences.remove(_storageKey);
      } else {
        _preferences.setString(_storageKey, sessionId);
      }
      return;
    }
  }

  String? _extractSessionId(String rawCookie) {
    final parts = rawCookie.split(';');
    if (parts.isEmpty) {
      return null;
    }

    final nameValue = parts.first.trim();
    final separatorIndex = nameValue.indexOf('=');
    if (separatorIndex <= 0) {
      return null;
    }

    final cookieName = nameValue.substring(0, separatorIndex).trim();
    if (cookieName != _sessionCookieName) {
      return null;
    }

    return nameValue.substring(separatorIndex + 1).trim();
  }

  String? _asCookieHeader(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    if (value is Iterable<Object?>) {
      final cookies = value
          .whereType<String>()
          .map((String part) => part.trim())
          .where((String part) => part.isNotEmpty)
          .toList(growable: false);
      if (cookies.isEmpty) {
        return null;
      }
      return cookies.join('; ');
    }
    return null;
  }

  String _mergeCookieHeader(String existingHeader, String sessionCookie) {
    final parts = existingHeader
        .split(';')
        .map((String part) => part.trim())
        .where((String part) => part.isNotEmpty)
        .where((String part) => !part.startsWith('$_sessionCookieName='))
        .toList(growable: true);
    parts.add(sessionCookie);
    return parts.join('; ');
  }
}
