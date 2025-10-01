# flutter_launcher_mcp

An MCP server for launching and managing Flutter applications.

## Overview

`flutter_launcher_mcp` provides a Model Context Protocol (MCP) server that allows external clients (such as AI agents or IDEs) to programmatically launch Flutter applications and obtain their Dart Tooling Daemon (DTD) URI. It also provides a mechanism to gracefully terminate these launched processes.

This package aims to simplify the integration of Flutter development workflows with various tools by offering a standardized, language-agnostic interface for Flutter process management.

## Features

- **Launch Flutter Applications:** Start Flutter applications with custom arguments and retrieve their DTD URI.
- **Process Management:** Keep track of launched Flutter processes and terminate them when no longer needed.
- **Real-time DTD URI Retrieval:** Captures the DTD URI directly from the Flutter process's `stdout` stream.
- **MCP Compliant:** Exposes functionality via the Model Context Protocol for seamless integration with MCP-aware clients.
- **Testable Design:** Uses dependency injection for `ProcessManager` and `FileSystem` to facilitate unit testing.

## Installation

To use `flutter_launcher_mcp`, add it as a dependency to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_launcher_mcp: ^0.1.0
```

Then, run `dart pub get`.

## Usage

### Running the MCP Server

The `flutter_launcher_mcp` package provides an executable that runs the MCP server. You can start it from your terminal:

```bash
dart run flutter_launcher_mcp
```

This will start the server, listening for MCP requests on standard input/output. Clients can then connect to this server using the `dart_mcp` client library or any other MCP-compliant client.

### Available Tools

The server exposes the following tools:

#### `launch_app`

Launches a Flutter application with specified arguments and returns its DTD URI and process ID.

- **Description:** Launches a Flutter application and returns its DTD URI.
- **Input Schema:**

  ```json
  {
    "type": "object",
    "properties": {
      "root": {
        "type": "string",
        "description": "The root directory of the Flutter project."
      },
      "target": {
        "type": "string",
        "description": "The main entry point file of the application."
      },
      "device": {
        "type": "string",
        "description": "The device ID to launch the application on."
      }
    },
    "required": ["root", "device"]
  }
  ```

- **Output Schema:**

  ```json
  {
    "type": "object",
    "properties": {
      "dtdUri": {
        "type": "string",
        "description": "The DTD URI of the launched Flutter application."
      },
      "pid": {
        "type": "integer",
        "description": "The process ID of the launched Flutter application."
      }
    },
    "required": ["dtdUri", "pid"]
  }
  ```

- **Example Call (Conceptual):**

  ```dart
  // Assuming 'client' is an initialized ServerConnection from dart_mcp
  final launchResult = await client.callTool(
    CallToolRequest(
      name: 'launch_app',
      arguments: {
        'root': '/path/to/your/flutter/project',
        'device': 'emulator-5554',
      },
    ),
  );

  if (!launchResult.isError) {
    final dtdUri = launchResult.structuredContent!['dtdUri'] as String;
    final pid = launchResult.structuredContent!['pid'] as int;
    print('Flutter app launched! DTD URI: $dtdUri, PID: $pid');
  } else {
    print('Failed to launch Flutter app: ${launchResult.content.first.text}');
  }
  ```

#### `stop_app`

Kills a running Flutter process managed by this server.

- **Description:** Kills a running Flutter process managed by this server.
- **Input Schema:**

  ```json
  {
    "type": "object",
    "properties": {
      "pid": {
        "type": "integer",
        "description": "The process ID of the process to kill."
      }
    },
    "required": ["pid"]
  }
  ```

- **Output Schema:**

  ```json
  {
    "type": "object",
    "properties": {
      "success": {
        "type": "boolean",
        "description": "Whether the process was killed successfully."
      }
    },
    "required": ["success"]
  }
  ```

- **Example Call (Conceptual):**

  ```dart
  // Assuming 'client' is an initialized ServerConnection from dart_mcp
  // and 'launchedPid' is the PID obtained from a previous launchFlutter call
  final killResult = await client.callTool(
    CallToolRequest(
      name: 'stop_app',
      arguments: {'pid': launchedPid},
    ),
  );

  if (!killResult.isError) {
    final success = killResult.structuredContent!['success'] as bool;
    print('Kill process result: $success');
  } else {
    print('Failed to kill process: ${killResult.content.first.text}');
  }
  ```

## Development

### Running Tests

To run the unit tests for `flutter_launcher_mcp`:

```bash
dart test
```

### Code Formatting and Analysis

To format your code and run static analysis:

```bash
dart format .
dart fix --apply
dart analyze
```

## Contributing

Contributions are welcome! Please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the [LICENSE](LICENSE) file.
