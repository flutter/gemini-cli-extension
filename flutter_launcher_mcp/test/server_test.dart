// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:fake_async/fake_async.dart';
import 'package:file/memory.dart';
import 'package:flutter_launcher_mcp/src/server.dart';
import 'package:flutter_launcher_mcp/src/utils/sdk.dart';
import 'package:process/process.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart' as test;

void main() {
  test.group('FlutterLauncherMCPServer', () {
    late MemoryFileSystem fileSystem;
    late FlutterLauncherMCPServer server;
    late ServerConnection client;

    void createServerAndClient({required ProcessManager processManager}) {
      final channel = StreamChannelController<String>();
      server = FlutterLauncherMCPServer(
        channel.local,
        processManager: processManager,
        fileSystem: fileSystem,
        sdk: Sdk(flutterSdkPath: '/path/to/flutter/sdk'),
      );
      client = ServerConnection.fromStreamChannel(channel.foreign);
    }

    test.setUp(() {
      fileSystem = MemoryFileSystem();
    });

    test.tearDown(() async {
      await server.shutdown();
      await client.shutdown();
    });

    test.test('launch_app tool returns DTD URI and PID on success', () async {
      final dtdUri = 'ws://127.0.0.1:12345/abcdefg=';
      final processPid = 54321;
      final mockProcessManager = MockProcessManager(
        stdout: 'The Dart Tooling Daemon is available at: $dtdUri\n',
        pid: processPid,
      );
      createServerAndClient(processManager: mockProcessManager);

      // Initialize
      final initResult = await client.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
        ),
      );
      test.expect(initResult.serverInfo.name, 'Flutter Launcher MCP Server');
      client.notifyInitialized();

      // Call the tool
      final result = await client.callTool(
        CallToolRequest(
          name: 'launch_app',
          arguments: {
            'root':
                '/Users/gspencer/code/gemini-cli-extension/flutter_launcher_mcp',
            'device': 'test-device',
          },
        ),
      );

      test.expect(result.isError, test.isNot(true));
      test.expect(result.structuredContent, {
        'dtdUri': dtdUri,
        'pid': processPid,
      });
    });

    test.test(
      'launch_app tool returns DTD URI and PID on success from stderr',
      () async {
        final dtdUri = 'ws://127.0.0.1:12345/abcdefg=';
        final processPid = 54321;
        final mockProcessManager = MockProcessManager(
          stderr: 'The Dart Tooling Daemon is available at: $dtdUri\n',
          pid: processPid,
        );
        createServerAndClient(processManager: mockProcessManager);

        // Initialize
        final initResult = await client.initialize(
          InitializeRequest(
            protocolVersion: ProtocolVersion.latestSupported,
            capabilities: ClientCapabilities(),
            clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
          ),
        );
        test.expect(initResult.serverInfo.name, 'Flutter Launcher MCP Server');
        client.notifyInitialized();

        // Call the tool
        final result = await client.callTool(
          CallToolRequest(
            name: 'launch_app',
            arguments: {
              'root':
                  '/Users/gspencer/code/gemini-cli-extension/flutter_launcher_mcp',
              'device': 'test-device',
            },
          ),
        );

        test.expect(result.isError, test.isNot(true));
        test.expect(result.structuredContent, {
          'dtdUri': dtdUri,
          'pid': processPid,
        });
      },
    );

    test.test(
      'launch_app tool returns error if process exits before DTD URI',
      () async {
        final exitCodeCompleter = Completer<int>();
        final mockProcessManager = MockProcessManager(
          stdout: 'Some other output that does not contain the DTD URI.',
          exitCode: exitCodeCompleter.future,
        );
        createServerAndClient(processManager: mockProcessManager);

        // Initialize
        await client.initialize(
          InitializeRequest(
            protocolVersion: ProtocolVersion.latestSupported,
            capabilities: ClientCapabilities(),
            clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
          ),
        );
        client.notifyInitialized();

        // Call the tool
        final callToolFuture = client.callTool(
          CallToolRequest(
            name: 'launch_app',
            arguments: {
              'root':
                  '/Users/gspencer/code/gemini-cli-extension/flutter_launcher_mcp',
              'device': 'test-device',
            },
          ),
        );
        // Simulate the process exiting after a short delay
        unawaited(
          Future.delayed(
            Duration(milliseconds: 10),
          ).then((_) => exitCodeCompleter.complete(1)),
        );
        final result = await callToolFuture;
        test.expect(result.isError, true);
        final content = result.content.single as TextContent;
        test.expect(content.text, test.contains('exited with code 1'));
      },
    );

    test.test('stop_app tool successfully kills a running process', () async {
      final dtdUri = 'ws://127.0.0.1:12345/abcdefg=';
      final processPid = 54321;
      final mockProcessManager = MockProcessManager(
        stdout: 'The Dart Tooling Daemon is available at: $dtdUri\n',
        pid: processPid,
      );
      createServerAndClient(processManager: mockProcessManager);

      // Initialize
      await client.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
        ),
      );
      client.notifyInitialized();

      // Launch a process first
      final launchResult = await client.callTool(
        CallToolRequest(
          name: 'launch_app',
          arguments: {
            'root':
                '/Users/gspencer/code/gemini-cli-extension/flutter_launcher_mcp',
            'device': 'test-device',
          },
        ),
      );
      test.expect(launchResult.isError, test.isNot(true));
      final launchedPid = launchResult.structuredContent!['pid'] as int;

      // Now kill it
      final killResult = await client.callTool(
        CallToolRequest(name: 'stop_app', arguments: {'pid': launchedPid}),
      );
      mockProcessManager._exitCodeCompleter.complete(0);

      test.expect(killResult.isError, test.isNot(true));
      test.expect(killResult.structuredContent, {'success': true});
    });

    test.test(
      'launch_app tool passes deviceId to flutter run',
      () async {
        final dtdUri = 'ws://127.0.0.1:12345/abcdefg=';
        final processPid = 54321;
        final mockProcessManager = MockProcessManager(
          stdout: 'The Dart Tooling Daemon is available at: $dtdUri\n',
          pid: processPid,
        );
        createServerAndClient(processManager: mockProcessManager);

        // Initialize
        await client.initialize(
          InitializeRequest(
            protocolVersion: ProtocolVersion.latestSupported,
            capabilities: ClientCapabilities(),
            clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
          ),
        );
        client.notifyInitialized();

        // Call the tool
        await client.callTool(
          CallToolRequest(
            name: 'launch_app',
            arguments: {
              'root':
                  '/Users/gspencer/code/gemini-cli-extension/flutter_launcher_mcp',
              'device': 'test-device-id',
            },
          ),
        );

        test.expect(
          mockProcessManager.command,
          test.containsAll(['--device-id', 'test-device-id']),
        );
      },
      timeout: test.Timeout(Duration(seconds: 95)),
    );

    test.test('list_devices tool returns a list of devices', () async {
      final mockProcessManager = MockProcessManager(
        stdout: jsonEncode([
          {'id': 'device1'},
          {'id': 'device2'},
        ]),
      );
      createServerAndClient(processManager: mockProcessManager);

      // Initialize
      await client.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
        ),
      );
      client.notifyInitialized();

      // Call the tool
      final result = await client.callTool(
        CallToolRequest(name: 'list_devices', arguments: {}),
      );

      test.expect(result.isError, test.isNot(true));
      test.expect(result.structuredContent, {
        'devices': ['device1', 'device2'],
      });
    });

    test.test('get_app_logs tool returns logs for a running process', () async {
      final dtdUri = 'ws://127.0.0.1:12345/abcdefg=';
      final processPid = 54321;
      final exitCodeCompleter = Completer<int>();
      final mockProcessManager = MockProcessManager(
        stdout: 'The Dart Tooling Daemon is available at: $dtdUri\n',
        stderr: 'Some error output.',
        pid: processPid,
        exitCode: exitCodeCompleter.future,
      );
      createServerAndClient(processManager: mockProcessManager);

      // Initialize
      await client.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
        ),
      );
      client.notifyInitialized();

      // Launch a process first
      final launchResult = await client.callTool(
        CallToolRequest(
          name: 'launch_app',
          arguments: {
            'root':
                '/Users/gspencer/code/gemini-cli-extension/flutter_launcher_mcp',
            'device': 'test-device',
          },
        ),
      );
      test.expect(launchResult.isError, test.isNot(true));
      final launchedPid = launchResult.structuredContent!['pid'] as int;

      // Now get the logs
      final logsResult = await client.callTool(
        CallToolRequest(name: 'get_app_logs', arguments: {'pid': launchedPid}),
      );

      test.expect(logsResult.isError, test.isNot(true));
      test.expect(logsResult.structuredContent, {
        'logs': [
          '[stdout] The Dart Tooling Daemon is available at: $dtdUri',
          '[stderr] Some error output.',
        ],
      });

      // Try to get logs for a non-existent process
      final badLogsResult = await client.callTool(
        CallToolRequest(name: 'get_app_logs', arguments: {'pid': 99999}),
      );
      test.expect(badLogsResult.isError, true);

      // Stop the app and then try to get logs again.
      await client.callTool(
        CallToolRequest(name: 'stop_app', arguments: {'pid': launchedPid}),
      );
      exitCodeCompleter.complete(0);
      // Give the process time to exit and be cleaned up.
      await Future.delayed(const Duration(milliseconds: 10));
      final logsAfterStopResult = await client.callTool(
        CallToolRequest(name: 'get_app_logs', arguments: {'pid': launchedPid}),
      );
      test.expect(logsAfterStopResult.isError, true);
    });

    test.test(
      'list_devices tool returns an empty list when no devices found',
      () async {
        final mockProcessManager = MockProcessManager(stdout: '');
        createServerAndClient(processManager: mockProcessManager);

        // Initialize
        await client.initialize(
          InitializeRequest(
            protocolVersion: ProtocolVersion.latestSupported,
            capabilities: ClientCapabilities(),
            clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
          ),
        );
        client.notifyInitialized();

        // Call the tool
        final result = await client.callTool(
          CallToolRequest(name: 'list_devices', arguments: {}),
        );

        test.expect(result.isError, test.isNot(true));
        test.expect(result.structuredContent, {'devices': []});
      },
    );

    test.test(
      'list_running_apps tool returns a list of running apps',
      () async {
        final dtdUri = 'ws://127.0.0.1:12345/abcdefg=';
        final processPid = 54321;
        var mockProcessManager = MockProcessManager(
          stdout: 'The Dart Tooling Daemon is available at: $dtdUri\n',
          pid: processPid,
        );
        createServerAndClient(processManager: mockProcessManager);

        // Initialize
        await client.initialize(
          InitializeRequest(
            protocolVersion: ProtocolVersion.latestSupported,
            capabilities: ClientCapabilities(),
            clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
          ),
        );
        client.notifyInitialized();

        // Call list_running_apps when no apps are running
        var result = await client.callTool(
          CallToolRequest(name: 'list_running_apps', arguments: {}),
        );
        test.expect(result.isError, test.isNot(true));
        test.expect(result.structuredContent, {'apps': []});

        // Launch a process first
        final launchResult = await client.callTool(
          CallToolRequest(
            name: 'launch_app',
            arguments: {'root': '/some/path', 'device': 'test-device'},
          ),
        );
        test.expect(launchResult.isError, test.isNot(true));
        final launchedPid = launchResult.structuredContent!['pid'] as int;
        final launchedDtdUri =
            launchResult.structuredContent!['dtdUri'] as String;

        // Call list_running_apps again
        result = await client.callTool(
          CallToolRequest(name: 'list_running_apps', arguments: {}),
        );
        test.expect(result.isError, test.isNot(true));
        test.expect(result.structuredContent, {
          'apps': [
            {'pid': launchedPid, 'dtdUri': launchedDtdUri},
          ],
        });

        // Stop the app
        await client.callTool(
          CallToolRequest(name: 'stop_app', arguments: {'pid': launchedPid}),
        );
        mockProcessManager._exitCodeCompleter.complete(0);
        // Give the process time to exit and be cleaned up.
        await Future.delayed(const Duration(milliseconds: 10));

        // Call list_running_apps one more time
        result = await client.callTool(
          CallToolRequest(name: 'list_running_apps', arguments: {}),
        );
        test.expect(result.isError, test.isNot(true));
        test.expect(result.structuredContent, {'apps': []});
      },
    );

    test.test(
      'launched app is removed from running apps list when process exits',
      () async {
        final dtdUri = 'ws://127.0.0.1:12345/abcdefg=';
        final processPid = 54322; // Use a different PID for this test
        final exitCodeCompleter = Completer<int>();
        final mockProcessManager = MockProcessManager(
          stdout: 'The Dart Tooling Daemon is available at: $dtdUri\n',
          pid: processPid,
          exitCode: exitCodeCompleter.future,
        );
        createServerAndClient(processManager: mockProcessManager);

        // Initialize
        await client.initialize(
          InitializeRequest(
            protocolVersion: ProtocolVersion.latestSupported,
            capabilities: ClientCapabilities(),
            clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
          ),
        );
        client.notifyInitialized();

        // Launch the app
        final launchResult = await client.callTool(
          CallToolRequest(
            name: 'launch_app',
            arguments: {'root': '/some/path', 'device': 'test-device'},
          ),
        );
        test.expect(launchResult.isError, test.isNot(true));
        final launchedPid = launchResult.structuredContent!['pid'] as int;
        final launchedDtdUri =
            launchResult.structuredContent!['dtdUri'] as String;

        // Verify it's in the running apps list
        var result = await client.callTool(
          CallToolRequest(name: 'list_running_apps', arguments: {}),
        );
        test.expect(result.isError, test.isNot(true));
        test.expect(result.structuredContent, {
          'apps': [
            {'pid': launchedPid, 'dtdUri': launchedDtdUri},
          ],
        });

        // Simulate the process exiting
        exitCodeCompleter.complete(0);

        // Give some time for the exit handler to run
        await Future<void>.delayed(Duration(milliseconds: 100));

        // Verify it's removed from the running apps list
        result = await client.callTool(
          CallToolRequest(name: 'list_running_apps', arguments: {}),
        );
        test.expect(result.isError, test.isNot(true));
        test.expect(result.structuredContent, {'apps': []});
      },
    );

    test.test('launchApp cleans up process on timeout', () {
      fakeAsync((async) {
        final fileSystem = MemoryFileSystem();
        final mockProcessManager = MockProcessManager(
          // Never emit the DTD URI to cause a timeout.
          stdout: '',
        );
        final channel = StreamChannelController<String>();
        final server = FlutterLauncherMCPServer(
          channel.local,
          processManager: mockProcessManager,
          fileSystem: fileSystem,
          sdk: Sdk(flutterSdkPath: '/path/to/flutter/sdk'),
        );
        final client = ServerConnection.fromStreamChannel(channel.foreign);

        // Initialize
        client.initialize(
          InitializeRequest(
            protocolVersion: ProtocolVersion.latestSupported,
            capabilities: ClientCapabilities(),
            clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
          ),
        );
        client.notifyInitialized();
        async.flushMicrotasks();

        // Call the tool and expect a timeout.
        final future = client.callTool(
          CallToolRequest(
            name: 'launch_app',
            arguments: {'root': '/some/path', 'device': 'test-device'},
          ),
        );
        async.flushMicrotasks();

        // Elapse time to trigger the timeout.
        async.elapse(const Duration(seconds: 90));
        async.flushMicrotasks();

        // Now the future should be complete.
        future.then((result) {
          test.expect(result.isError, true);
          test.expect(
            (result.content.single as TextContent).text,
            test.contains('TimeoutException'),
          );
          test.expect(mockProcessManager.lastProcess?.killed, test.isTrue);
        });
        async.flushMicrotasks();
        server.shutdown();
        client.shutdown();
        async.flushMicrotasks();
      });
    });

    test.test('launch_app tool passes target to flutter run', () async {
      final dtdUri = 'ws://127.0.0.1:12345/abcdefg=';
      final processPid = 54321;
      final mockProcessManager = MockProcessManager(
        stdout: 'The Dart Tooling Daemon is available at: $dtdUri\n',
        pid: processPid,
      );
      createServerAndClient(processManager: mockProcessManager);

      // Initialize
      await client.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
        ),
      );
      client.notifyInitialized();

      // Call the tool
      await client.callTool(
        CallToolRequest(
          name: 'launch_app',
          arguments: {
            'root': '/some/path',
            'device': 'test-device',
            'target': 'lib/other_main.dart',
          },
        ),
      );

      test.expect(
        mockProcessManager.command,
        test.containsAll(['--target', 'lib/other_main.dart']),
      );
    });

    test.test('launch_app tool handles process start exception', () async {
      final mockProcessManager = MockProcessManager(shouldThrowOnStart: true);
      createServerAndClient(processManager: mockProcessManager);

      // Initialize
      await client.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
        ),
      );
      client.notifyInitialized();

      // Call the tool
      final result = await client.callTool(
        CallToolRequest(
          name: 'launch_app',
          arguments: {'root': '/some/path', 'device': 'test-device'},
        ),
      );

      test.expect(result.isError, true);
      test.expect(
        (result.content.single as TextContent).text,
        test.contains('Failed to launch Flutter application'),
      );
    });

    test.test('list_devices tool handles non-zero exit code', () async {
      final mockProcessManager = MockProcessManager(
        stderr: 'Something went wrong',
        exitCode: Future.value(1),
      );
      createServerAndClient(processManager: mockProcessManager);

      // Initialize
      await client.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
        ),
      );
      client.notifyInitialized();

      // Call the tool
      final result = await client.callTool(
        CallToolRequest(name: 'list_devices', arguments: {}),
      );

      test.expect(result.isError, true);
      test.expect(
        (result.content.single as TextContent).text,
        test.contains('Failed to list Flutter devices'),
      );
    });

    test.test('list_devices tool handles invalid JSON', () async {
      final mockProcessManager = MockProcessManager(stdout: 'not json');
      createServerAndClient(processManager: mockProcessManager);

      // Initialize
      await client.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
        ),
      );
      client.notifyInitialized();

      // Call the tool
      final result = await client.callTool(
        CallToolRequest(name: 'list_devices', arguments: {}),
      );

      test.expect(result.isError, true);
      test.expect(
        (result.content.single as TextContent).text,
        test.contains('Failed to list Flutter devices'),
      );
    });

    test.test('stop_app tool handles non-existent PID', () async {
      final mockProcessManager = MockProcessManager();
      createServerAndClient(processManager: mockProcessManager);

      // Initialize
      await client.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
        ),
      );
      client.notifyInitialized();

      // Call the tool
      final result = await client.callTool(
        CallToolRequest(name: 'stop_app', arguments: {'pid': 999}),
      );

      test.expect(result.isError, true);
      test.expect(
        (result.content.single as TextContent).text,
        test.contains('Application with PID 999 not found'),
      );
    });

    test.test('stop_app tool handles kill failure', () async {
      final dtdUri = 'ws://127.0.0.1:12345/abcdefg=';
      final processPid = 54321;
      final mockProcessManager = MockProcessManager(
        stdout: 'The Dart Tooling Daemon is available at: $dtdUri\n',
        pid: processPid,
        killResult: false,
      );
      createServerAndClient(processManager: mockProcessManager);

      // Initialize
      await client.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
        ),
      );
      client.notifyInitialized();

      // Launch a process first
      final launchResult = await client.callTool(
        CallToolRequest(
          name: 'launch_app',
          arguments: {'root': '/some/path', 'device': 'test-device'},
        ),
      );
      final launchedPid = launchResult.structuredContent!['pid'] as int;

      // Now kill it
      final killResult = await client.callTool(
        CallToolRequest(name: 'stop_app', arguments: {'pid': launchedPid}),
      );

      test.expect(killResult.isError, test.isNot(true));
      test.expect(killResult.structuredContent, {'success': false});
    });

    test.test('shutdown kills running processes', () async {
      final dtdUri = 'ws://127.0.0.1:12345/abcdefg=';
      final processPid = 54321;
      final mockProcessManager = MockProcessManager(
        stdout: 'The Dart Tooling Daemon is available at: $dtdUri\n',
        pid: processPid,
      );
      createServerAndClient(processManager: mockProcessManager);

      // Initialize
      await client.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
        ),
      );
      client.notifyInitialized();

      // Launch a process
      final launchResult = await client.callTool(
        CallToolRequest(
          name: 'launch_app',
          arguments: {'root': '/some/path', 'device': 'test-device'},
        ),
      );
      final launchedPid = launchResult.structuredContent!['pid'] as int;

      // Shutdown the server
      await server.shutdown();

      // Verify that killPid was called
      test.expect(mockProcessManager.killedPids, [launchedPid]);
    });
  });
}

class MockProcessManager implements ProcessManager {
  final Stream<List<int>> stdout;
  final Stream<List<int>> stderr;
  final Completer<int> _exitCodeCompleter;
  final int pid;
  final bool killResult;
  List<Object>? command;
  MockProcess? lastProcess;
  bool shouldThrowOnStart;
  final killedPids = <int>[];

  MockProcessManager({
    String? stdout,
    String? stderr,
    Future<int>? exitCode,
    this.pid = 12345,
    this.killResult = true,
    this.shouldThrowOnStart = false,
  }) : stdout = Stream.value(utf8.encode(stdout ?? '')),
       stderr = Stream.value(utf8.encode(stderr ?? '')),
       _exitCodeCompleter = Completer<int>() {
    if (exitCode != null) {
      exitCode.then((value) => _exitCodeCompleter.complete(value));
    }
  }

  @override
  Future<Process> start(
    List<Object> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    if (shouldThrowOnStart) {
      throw Exception('Failed to start process');
    }
    this.command = command;
    final process = MockProcess(
      stdout: stdout,
      stderr: stderr,
      pid: pid,
      exitCodeCompleter: _exitCodeCompleter,
    );
    lastProcess = process;
    return process;
  }

  @override
  bool killPid(int pid, [ProcessSignal signal = ProcessSignal.sigterm]) {
    killedPids.add(pid);
    return killResult;
  }

  @override
  Future<ProcessResult> run(
    List<Object> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) async {
    this.command = command;
    final stdoutResult = await stdout.toList();
    final stderrResult = await stderr.toList();
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(0);
    }
    return ProcessResult(
      pid,
      await _exitCodeCompleter.future,
      utf8.decode(stdoutResult.expand((x) => x).toList()),
      utf8.decode(stderrResult.expand((x) => x).toList()),
    );
  }

  @override
  bool canRun(executable, {String? workingDirectory}) {
    throw UnimplementedError();
  }

  @override
  ProcessResult runSync(
    List<Object> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) {
    throw UnimplementedError();
  }
}

class MockProcess implements Process {
  @override
  final Stream<List<int>> stdout;
  @override
  final Stream<List<int>> stderr;
  @override
  final int pid;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;
  final Completer<int> _exitCodeCompleter;

  bool killed = false;

  MockProcess({
    required this.stdout,
    required this.stderr,
    required this.pid,
    required Completer<int> exitCodeCompleter,
  }) : _exitCodeCompleter = exitCodeCompleter;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(-9); // SIGKILL
    }
    return true;
  }

  @override
  late final IOSink stdin = throw UnimplementedError();
}
