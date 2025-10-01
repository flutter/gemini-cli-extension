// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A library for locating and interacting with the Dart and Flutter SDKs.
library;

import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:path/path.dart' as p;

/// An interface that provides access to an [Sdk] instance.
///
/// This provides information about the Dart and Flutter SDKs, if available.
abstract interface class SdkSupport {
  /// The SDK instance containing path information.
  Sdk get sdk;
}

/// Information about the Dart and Flutter SDKs.
///
/// This class provides the paths to the Dart and Flutter SDKs, as well as
/// convenience getters for the executable paths.
class Sdk {
  /// The path to the root of the Dart SDK.
  final String? dartSdkPath;

  /// The path to the root of the Flutter SDK.
  final String? flutterSdkPath;

  /// Creates a new [Sdk] instance.
  Sdk({this.dartSdkPath, this.flutterSdkPath});

  /// Creates an [Sdk] instance by attempting to locate the SDKs.
  ///
  /// If [dartSdkPath] is not provided, it defaults to the directory containing
  /// the currently running Dart executable. It validates the path by checking
  /// for the existence of a `version` file.
  ///
  /// If [flutterSdkPath] is not provided, it searches up from the Dart SDK
  /// path to see if it is nested inside a Flutter SDK (e.g., in the
  /// `bin/cache` directory).
  ///
  /// Throws an [ArgumentError] if the Dart SDK path is invalid.
  factory Sdk.find({
    String? dartSdkPath,
    String? flutterSdkPath,
    void Function(LoggingLevel, String)? log,
  }) {
    log?.call(LoggingLevel.debug, 'Finding SDKs...');
    // Assume that we are running from the Dart SDK bin dir if not given any
    // other configuration.
    dartSdkPath ??= p.dirname(p.dirname(Platform.resolvedExecutable));
    log?.call(LoggingLevel.debug, 'Using Dart SDK path: $dartSdkPath');

    final versionFile = dartSdkPath.child('version');
    if (!File(versionFile).existsSync()) {
      log?.call(
        LoggingLevel.warning,
        'Invalid Dart SDK path, no version file found.',
      );
      throw ArgumentError('Invalid Dart SDK path: $dartSdkPath');
    }

    // Check if this is nested inside a Flutter SDK.
    if (dartSdkPath.parent case final cacheDir
        when cacheDir.basename == 'cache' && flutterSdkPath == null) {
      log?.call(
        LoggingLevel.debug,
        'Dart SDK appears to be in a `cache` directory.',
      );
      if (cacheDir.parent case final binDir when binDir.basename == 'bin') {
        log?.call(LoggingLevel.debug, 'Found `bin` directory above `cache`.');
        final flutterExecutable = binDir.child(
          'flutter${Platform.isWindows ? '.bat' : ''}',
        );
        if (File(flutterExecutable).existsSync()) {
          flutterSdkPath = binDir.parent;
          log?.call(
            LoggingLevel.debug,
            'Found Flutter SDK at: $flutterSdkPath',
          );
        }
      }
    }

    return Sdk(dartSdkPath: dartSdkPath, flutterSdkPath: flutterSdkPath);
  }

  /// The path to the `dart` executable.
  ///
  /// Throws an [ArgumentError] if [dartSdkPath] is `null`.
  String get dartExecutablePath =>
      dartSdkPath
          ?.child('bin')
          .child('dart${Platform.isWindows ? '.exe' : ''}') ??
      (throw ArgumentError(
        'Dart SDK location unknown, try setting the DART_SDK environment '
        'variable.',
      ));

  /// The path to the `flutter` executable.
  ///
  /// Throws an [ArgumentError] if [flutterSdkPath] is `null`.
  String get flutterExecutablePath =>
      flutterSdkPath
          ?.child('bin')
          .child('flutter${Platform.isWindows ? '.bat' : ''}') ??
      (throw ArgumentError(
        'Flutter SDK location unknown. To work on flutter projects, you must '
        'spawn the server using `dart` from the flutter SDK and not a Dart '
        'SDK, or set a FLUTTER_SDK environment variable.',
      ));
}

extension on String {
  String get basename => p.basename(this);
  String child(String path) => p.join(this, path);
  String get parent => p.dirname(this);
}
