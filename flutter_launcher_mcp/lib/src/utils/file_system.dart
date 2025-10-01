// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A library for file system access within the MCP server.
library;

import 'package:file/file.dart';

/// An interface that provides access to a [FileSystem] instance.
///
/// MCP server classes and mixins that interact with the file system should
/// implement this interface. This allows for the injection of a mock
/// [FileSystem] during testing, instead of interacting with the real file
/// system via `dart:io`.
abstract interface class FileSystemSupport {
  /// The file system instance to use for all file operations.
  FileSystem get fileSystem;
}
