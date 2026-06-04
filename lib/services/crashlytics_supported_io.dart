import 'dart:io' show Platform;

/// Yalnizca Android/iOS gercek cihaz.
bool get isCrashlyticsNativeSdkSupported =>
    Platform.isAndroid || Platform.isIOS;
