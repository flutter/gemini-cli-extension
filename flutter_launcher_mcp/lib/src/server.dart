// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The main entry point for the Flutter Launcher MCP server.
library;

import 'package:dart_mcp/server.dart';
import 'package:file/file.dart';
import 'package:process/process.dart';

import 'mixins/flutter_launcher.dart';
import 'utils/file_system.dart';
import 'utils/process_manager.dart';
import 'utils/sdk.dart';

/// An MCP server for launching and managing Flutter applications.
///
/// This server composes its functionality from various mixins, including
/// [FlutterLauncherSupport] for handling Flutter-specific tasks. It implements
/// [ProcessManagerSupport], [FileSystemSupport], and [SdkSupport] to provide
// dependencies to the mixins that require them.
final class FlutterLauncherMCPServer extends MCPServer
    with
        LoggingSupport,
        ToolsSupport,
        RootsTrackingSupport,
        FlutterLauncherSupport
    implements ProcessManagerSupport, FileSystemSupport, SdkSupport {
  @override
  final Sdk sdk;

  @override
  final ProcessManager processManager;

  @override
  final FileSystem fileSystem;

  /// Creates a new instance of the [FlutterLauncherMCPServer].
  ///
  /// The server is initialized with the required [sdk], [processManager], and
  /// [fileSystem] instances, which are then made available to the various
  /// mixins.
  FlutterLauncherMCPServer(
    super.channel, {
    required this.sdk,
    required this.processManager,
    required this.fileSystem,
    LoggingLevel initialLogLevel = LoggingLevel.info,
  }) : super.fromStreamChannel(
         implementation: Implementation(
           name: 'Flutter Launcher MCP Server',
           version: '0.1.0',
         ),
         instructions:
             'Provides tools to launch and manage Flutter applications.',
       ) {
    loggingLevel = initialLogLevel;
    log(LoggingLevel.info, 'FlutterLauncherMCPServer started.');
  }
}
