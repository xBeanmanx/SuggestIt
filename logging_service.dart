import 'package:logger/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

// Logging levels for the application
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
  fatal,
}

// Custom logger that wraps the logger package and adds additional functionality
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  late Logger _logger;
  late DeviceInfoPlugin _deviceInfo;
  PackageInfo? _packageInfo;
  bool _isInitialized = false;

  factory AppLogger() {
    return _instance;
  }

  AppLogger._internal() {
    _initialize();
  }

  Future<void> _initialize() async {
    _deviceInfo = DeviceInfoPlugin();
    
    // Configure logger
    if (kReleaseMode) {
      _logger = Logger(
        filter: ProductionFilter(),
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 5,
          lineLength: 120,
          colors: false,
          printEmojis: false,
          printTime: true,
        ),
      );
    } else {
      // In debug mode, use detailed output
      _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 2,
          errorMethodCount: 8,
          lineLength: 120,
          colors: true,
          printEmojis: true,
          printTime: true,
        ),
      );
    }
    
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (e) {
      _logger.w('Failed to get package info: $e');
    }
    
    _isInitialized = true;
  }

  // Helper method to format message with tag
  String _formatMessage(String message, {String? tag}) {
    return tag != null ? '[$tag] $message' : message;
  }

  // Log a verbose message
  void v(String message, {dynamic error, StackTrace? stackTrace, String? tag}) {
    if (!_isInitialized) return;
    _log(Level.verbose, message, error: error, stackTrace: stackTrace, tag: tag);
  }

  // Log a debug message
  void d(String message, {dynamic error, StackTrace? stackTrace, String? tag}) {
    if (!_isInitialized) return;
    _log(Level.debug, message, error: error, stackTrace: stackTrace, tag: tag);
  }

  // Log an info message
  void i(String message, {dynamic error, StackTrace? stackTrace, String? tag}) {
    if (!_isInitialized) return;
    _log(Level.info, message, error: error, stackTrace: stackTrace, tag: tag);
  }

  // Log a warning message
  void w(String message, {dynamic error, StackTrace? stackTrace, String? tag}) {
    if (!_isInitialized) return;
    _log(Level.warning, message, error: error, stackTrace: stackTrace, tag: tag);
  }

  // Log an error message
  void e(String message, {dynamic error, StackTrace? stackTrace, String? tag}) {
    if (!_isInitialized) return;
    _log(Level.error, message, error: error, stackTrace: stackTrace, tag: tag);
  }

  // Log a fatal error message (highest level)
  void f(String message, {dynamic error, StackTrace? stackTrace, String? tag}) {
    if (!_isInitialized) return;
    _log(Level.fatal, message, error: error, stackTrace: stackTrace, tag: tag);
  }

  // Log network requests and responses
  void network(String url, {String method = 'GET', int? statusCode, dynamic request, dynamic response, int? durationMs}) {
    if (!_isInitialized) return;
    
    final message = StringBuffer('$method $url');
    if (statusCode != null) message.write(' → $statusCode');
    if (durationMs != null) message.write(' (${durationMs}ms)');
    
    _log(Level.info, message.toString(), tag: 'NETWORK');
    
    if (request != null) {
      _log(Level.debug, 'Request: $request', tag: 'NETWORK');
    }
    
    if (response != null) {
      _log(Level.debug, 'Response: $response', tag: 'NETWORK');
    }
  }

  // Log Firebase operations
  void firebase(String operation, {String? collection, String? documentId, dynamic data, dynamic error}) {
    if (!_isInitialized) return;
    
    final message = StringBuffer('Firebase $operation');
    if (collection != null) message.write(' on $collection');
    if (documentId != null) message.write('/$documentId');
    
    if (error != null) {
      _log(Level.error, message.toString(), error: error, tag: 'FIREBASE');
    } else {
      _log(Level.info, message.toString(), tag: 'FIREBASE');
      if (data != null) {
        _log(Level.debug, 'Data: $data', tag: 'FIREBASE');
      }
    }
  }

  // Log user actions
  void userAction(String action, {String? userId, Map<String, dynamic>? metadata}) {
    if (!_isInitialized) return;
    
    final message = StringBuffer('User action: $action');
    if (userId != null) message.write(' (user: $userId)');
    
    _log(Level.info, message.toString(), tag: 'USER');
    
    if (metadata != null && metadata.isNotEmpty) {
      _log(Level.debug, 'Metadata: $metadata', tag: 'USER');
    }
  }

  // Internal logging method
  void _log(Level level, String message, {dynamic error, StackTrace? stackTrace, String? tag}) {
    final formattedMessage = _formatMessage(message, tag: tag);
    
    switch (level) {
      case Level.verbose:
        _logger.t(formattedMessage, error: error, stackTrace: stackTrace);
        break;
      case Level.debug:
        _logger.d(formattedMessage, error: error, stackTrace: stackTrace);
        break;
      case Level.info:
        _logger.i(formattedMessage, error: error, stackTrace: stackTrace);
        break;
      case Level.warning:
        _logger.w(formattedMessage, error: error, stackTrace: stackTrace);
        break;
      case Level.error:
        _logger.e(formattedMessage, error: error, stackTrace: stackTrace);
        break;
      case Level.fatal:
        _logger.wtf(formattedMessage, error: error, stackTrace: stackTrace);
        break;
      case Level.all:
        // TODO: Handle this case.
        throw UnimplementedError();
      case Level.trace:
        // TODO: Handle this case.
        throw UnimplementedError();
      case Level.wtf:
        // TODO: Handle this case.
        throw UnimplementedError();
      case Level.nothing:
        // TODO: Handle this case.
        throw UnimplementedError();
      case Level.off:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
    
    // In release mode, also send critical errors to remote logging service
    if (kReleaseMode && (level == Level.error || level == Level.fatal)) {
      _sendToRemote(level, formattedMessage, error: error, stackTrace: stackTrace);
    }
  }

  // Send logs to remote service (Firebase Crashlytics, Sentry, etc.)
  Future<void> _sendToRemote(Level level, String message, {dynamic error, StackTrace? stackTrace}) async {
    try {
      // TODO: Integrate with your preferred remote logging service
      // Example with Firebase Crashlytics:
      // await FirebaseCrashlytics.instance.recordError(error, stackTrace);
      
      // For now, just log that we would send it
      _logger.i('Would send to remote: $message');
    } catch (e) {
      _logger.e('Failed to send log to remote service', error: e);
    }
  }

  // Get app and device info for debugging
  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    try {
      final deviceInfo = await _getDeviceInfo();
      return {
        'app': {
          'name': _packageInfo?.appName ?? 'Unknown',
          'version': _packageInfo?.version ?? 'Unknown',
          'build': _packageInfo?.buildNumber ?? 'Unknown',
        },
        'device': deviceInfo,
        'environment': {
          'mode': kReleaseMode ? 'release' : 'debug',
          'web': kIsWeb,
          'platform': defaultTargetPlatform.toString(),
        },
      };
    } catch (e) {
      _logger.e('Failed to get diagnostic info', error: e);
      return {};
    }
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        return {
          'type': 'web',
          'browser': webInfo.browserName.name,
          'platform': webInfo.platform,
          'userAgent': webInfo.userAgent,
        };
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'type': 'android',
          'brand': androidInfo.brand,
          'model': androidInfo.model,
          'version': androidInfo.version.release,
          'sdk': androidInfo.version.sdkInt,
        };
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'type': 'ios',
          'model': iosInfo.model,
          'systemVersion': iosInfo.systemVersion,
          'name': iosInfo.name,
        };
      }
    } catch (e) {
      _logger.e('Failed to get device info', error: e);
    }
    return {'type': 'unknown'};
  }

  // Set user ID for logging context
  void setUserId(String? userId) {
    if (userId != null) {
      _logger.i('Setting user context: $userId');
    }
  }

  // Clear user context
  void clearUserContext() {
    _logger.i('Clearing user context');
  }
}