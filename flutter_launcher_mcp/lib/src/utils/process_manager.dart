// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A library for managing processes within the MCP server.
library;

import 'package:process/process.dart';

/// An interface that provides access to a [ProcessManager] instance.
///
/// MCP server classes and mixins that spawn processes should implement this
/// interface. This allows for the injection of a mock [ProcessManager] during
/// testing, instead of making direct calls to `dart:io.Process`.
abstract interface class ProcessManagerSupport {
  /// The process manager to use for all process operations.
  ProcessManager get processManager;
}
