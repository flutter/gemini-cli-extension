// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A library for shared constants used throughout the MCP server.
library;

import 'package:dart_mcp/server.dart';

/// A namespace for all the parameter names used in MCP tools.
///
/// This extension on `Never` provides a centralized place to define and access
/// the string constants for tool parameter names, reducing the risk of typos.
extension ParameterNames on Never {
  /// The parameter name for a column number.
  static const column = 'column';

  /// The parameter name for a command.
  static const command = 'command';

  /// The parameter name for deleting conflicting outputs.
  static const deleteConflictingOutputs = 'delete-conflicting-outputs';

  /// The parameter name for a directory.
  static const directory = 'directory';

  /// The parameter name for the empty flag.
  static const empty = 'empty';

  /// The parameter name for a line number.
  static const line = 'line';

  /// The parameter name for a name identifier.
  static const name = 'name';

  /// The parameter name for a list of package names.
  static const packageNames = 'packageNames';

  /// The parameter name for a list of paths.
  static const paths = 'paths';

  /// The parameter name for a platform identifier.
  static const platform = 'platform';

  /// The parameter name for a position.
  static const position = 'position';

  /// The parameter name for a project type.
  static const projectType = 'projectType';

  /// The parameter name for a query string.
  static const query = 'query';

  /// The parameter name for a root directory.
  static const root = 'root';

  /// The parameter name for a list of root directories.
  static const roots = 'roots';

  /// The parameter name for a template identifier.
  static const template = 'template';

  /// The parameter name for test runner arguments.
  static const testRunnerArgs = 'testRunnerArgs';

  /// The parameter name for a URI.
  static const uri = 'uri';

  /// The parameter name for a list of URIs.
  static const uris = 'uris';

  /// The parameter name for a user journey.
  static const userJourney = 'user_journey';
}

/// A shared success response for tools.
final success = CallToolResult(content: [Content.text(text: 'Success')]);
