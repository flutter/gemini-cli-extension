// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A library for locating and interacting with the Dart and Flutter SDKs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:process/process.dart';

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
  String? dartSdkPath;

  /// The path to the root of the Flutter SDK.
  String? flutterSdkPath;

  /// Creates a new [Sdk] instance.
  Sdk({this.dartSdkPath, this.flutterSdkPath});

  /// Initializes the SDK paths by attempting to locate the SDKs.
  ///
  /// This method runs `flutter --version --machine` to find the Flutter SDK,
  /// and from that it derives the Dart SDK path. If `flutter` is not in the
  /// path or the command fails, the SDK paths will be null.
  Future<void> init({
    ProcessManager processManager = const LocalProcessManager(),
    FileSystem fileSystem = const LocalFileSystem(),
    void Function(LoggingLevel, String)? log,
  }) async {
    log?.call(LoggingLevel.debug, 'Finding SDKs...');
    try {
      final result = await processManager.run([
        'flutter',
        '--version',
        '--machine',
      ]);

      if (result.exitCode != 0) {
        log?.call(
          LoggingLevel.warning,
          'Failed to find Flutter SDK: `flutter --version --machine` failed with exit code ${result.exitCode}. '
          'Please ensure the Flutter SDK is in your path and restart the MCP server.',
        );
        return;
      }

      final json = jsonDecode(result.stdout as String);
      final foundFlutterSdkPath = json['flutterRoot'] as String?;
      if (foundFlutterSdkPath == null) {
        log?.call(
          LoggingLevel.warning,
          'Failed to find flutterRoot in `flutter --version --machine` output.',
        );
        return;
      }
      log?.call(
        LoggingLevel.debug,
        'Found Flutter SDK at: $foundFlutterSdkPath',
      );
      flutterSdkPath = foundFlutterSdkPath;

      final foundDartSdkPath = p.join(
        flutterSdkPath!,
        'bin',
        'cache',
        'dart-sdk',
      );
      final versionFile = p.join(foundDartSdkPath, 'version');
      if (!fileSystem.file(versionFile).existsSync()) {
        log?.call(
          LoggingLevel.warning,
          'Invalid Dart SDK path, no version file found at ${p.join(foundDartSdkPath, 'version')}.',
        );
        return;
      }
      log?.call(LoggingLevel.debug, 'Found Dart SDK at: $foundDartSdkPath');
      dartSdkPath = foundDartSdkPath;
    } on ProcessException catch (e) {
      log?.call(
        LoggingLevel.warning,
        'Failed to find Flutter SDK. The "flutter" command is not in your path or failed to run. '
        'Please ensure the Flutter SDK is in your path and restart the MCP server. Error: ${e.message}',
      );
    } catch (e, s) {
      log?.call(
        LoggingLevel.warning,
        'Exception while trying to find Flutter SDK: $e\n$s',
      );
    }
  }

  /// The path to the `dart` executable.
  String? get dartExecutablePath => dartSdkPath
      ?.child('bin')
      .child('dart${Platform.isWindows ? '.exe' : ''}');

  /// The path to the `flutter` executable.
  String? get flutterExecutablePath => flutterSdkPath
      ?.child('bin')
      .child('flutter${Platform.isWindows ? '.bat' : ''}');
}

extension on String {
  String child(String path) => p.join(this, path);
}
