// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A library for handling analytics within the MCP server.
library;

import 'package:dart_mcp/server.dart';
import 'package:unified_analytics/unified_analytics.dart';

/// Provides access to an [Analytics] instance for MCP servers.
///
/// The `DartMCPServer` class implements this class so that [Analytics]
/// methods can be easily mocked during testing.
abstract interface class AnalyticsSupport {
  /// The analytics instance, or `null` if analytics are disabled.
  Analytics? get analytics;
}

/// Defines the types of analytics events that can be tracked.
enum AnalyticsEvent {
  /// An event that is fired when a tool is called.
  callTool,

  /// An event that is fired when a resource is read.
  readResource,

  /// An event that is fired when a prompt is retrieved.
  getPrompt,
}

/// The metrics for a resources/read MCP handler.
final class ReadResourceMetrics extends CustomMetrics {
  /// The kind of resource that was read.
  ///
  /// We don't want to record the full URI.
  final ResourceKind kind;

  /// The length of the resource.
  final int length;

  /// The time it took to read the resource.
  final int elapsedMilliseconds;

  /// Creates a new instance of [ReadResourceMetrics].
  ReadResourceMetrics({
    required this.kind,
    required this.length,
    required this.elapsedMilliseconds,
  });

  @override
  Map<String, Object> toMap() => {
    _kind: kind.name,
    _length: length,
    _elapsedMilliseconds: elapsedMilliseconds,
  };
}

/// The metrics for a prompts/get MCP handler.
final class GetPromptMetrics extends CustomMetrics {
  /// The name of the prompt that was retrieved.
  final String name;

  /// Whether or not the prompt was given with arguments.
  final bool withArguments;

  /// The time it took to generate the prompt.
  final int elapsedMilliseconds;

  /// Whether or not the prompt call succeeded.
  final bool success;

  /// Creates a new instance of [GetPromptMetrics].
  GetPromptMetrics({
    required this.name,
    required this.withArguments,
    required this.elapsedMilliseconds,
    required this.success,
  });

  @override
  Map<String, Object> toMap() => {
    _name: name,
    _withArguments: withArguments,
    _elapsedMilliseconds: elapsedMilliseconds,
    _success: success,
  };
}

/// The metrics for a tools/call MCP handler.
final class CallToolMetrics extends CustomMetrics {
  /// The name of the tool that was invoked.
  final String tool;

  /// Whether or not the tool call succeeded.
  final bool success;

  /// The time it took to invoke the tool.
  final int elapsedMilliseconds;

  /// The reason for the failure, if [success] is `false`.
  final CallToolFailureReason? failureReason;

  /// Creates a new instance of [CallToolMetrics].
  CallToolMetrics({
    required this.tool,
    required this.success,
    required this.elapsedMilliseconds,
    required this.failureReason,
  });

  @override
  Map<String, Object> toMap() => {
    _tool: tool,
    _success: success,
    _elapsedMilliseconds: elapsedMilliseconds,
    if (failureReason != null) _failureReason: failureReason!.name,
  };
}

/// The kind of resource that was read.
enum ResourceKind {
  /// The runtime errors of the application.
  runtimeErrors,
}

/// An extension for attaching failure reasons to [CallToolResult] objects.
extension WithFailureReason on CallToolResult {
  static final _expando = Expando<CallToolFailureReason>();

  /// Gets the failure reason for this [CallToolResult].
  CallToolFailureReason? get failureReason => _expando[this as Object];

  /// Sets the failure reason for this [CallToolResult].
  set failureReason(CallToolFailureReason? value) =>
      _expando[this as Object] = value;
}

/// Known reasons for failed tool calls.
enum CallToolFailureReason {
  /// An error occurred due to invalid arguments.
  argumentError,

  /// The connected application's service is not supported.
  connectedAppServiceNotSupported,

  /// A DTD connection was attempted when one was already established.
  dtdAlreadyConnected,

  /// A DTD connection was required but not established.
  dtdNotConnected,

  /// Flutter driver was required but not enabled.
  flutterDriverNotEnabled,

  /// The provided path was invalid.
  invalidPath,

  /// The provided root path was invalid.
  invalidRootPath,

  /// The provided root URI scheme was invalid.
  invalidRootScheme,

  /// There was no active debug session.
  noActiveDebugSession,

  /// A required root was not provided.
  noRootGiven,

  /// No project roots have been set.
  noRootsSet,

  /// The requested command does not exist.
  noSuchCommand,

  /// A WebSocket exception occurred.
  webSocketException,
}

const _elapsedMilliseconds = 'elapsedMilliseconds';
const _failureReason = 'failureReason';
const _kind = 'kind';
const _length = 'length';
const _name = 'name';
const _success = 'success';
const _tool = 'tool';
const _withArguments = 'withArguments';
