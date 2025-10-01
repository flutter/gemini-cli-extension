// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:file/local.dart';
import 'package:flutter_launcher_mcp/src/server.dart';
import 'package:flutter_launcher_mcp/src/utils/sdk.dart';
import 'package:process/process.dart';

const logLevelOption = 'log-level';
const helpFlag = 'help';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      logLevelOption,
      help: 'The initial level of logging to show.',
      allowed: LoggingLevel.values.map((e) => e.name.toLowerCase()),
      defaultsTo: 'info',
    )
    ..addFlag(
      helpFlag,
      abbr: 'h',
      help: 'Shows this help message.',
      negatable: false,
    );
  final argResults = parser.parse(arguments);

  if (argResults[helpFlag] as bool) {
    stdout.writeln('A server for launching Flutter applications.\n');
    stdout.writeln(parser.usage);
    return;
  }

  final logLevel = LoggingLevel.values.firstWhere(
    (level) => level.name.toLowerCase() == argResults[logLevelOption],
  );

  const processManager = LocalProcessManager();
  const fileSystem = LocalFileSystem();
  final sdk = Sdk();

  final server = FlutterLauncherMCPServer(
    stdioChannel(input: stdin, output: stdout),
    sdk: sdk,
    processManager: processManager,
    fileSystem: fileSystem,
    initialLogLevel: logLevel,
  );

  await server.sdk.init(
    processManager: processManager,
    fileSystem: fileSystem,
    log: server.log,
  );
}
