// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A library of utility functions for command-line operations in the MCP
/// server.
library;

import 'dart:async';
import 'dart:io' as io;

import 'package:collection/collection.dart';
import 'package:dart_mcp/server.dart';
import 'package:file/file.dart';
import 'package:process/process.dart';
import 'package:yaml/yaml.dart';

import 'analytics.dart';
import 'constants.dart';
import 'sdk.dart';

/// The supported kinds of projects.
enum ProjectKind {
  /// A Flutter project.
  flutter,

  /// A Dart project.
  dart,

  /// An unknown project, this usually means there was no pubspec.yaml.
  unknown,
}

/// Infers the [ProjectKind] of a given project at [rootUri].
///
/// This is done by checking for the existence of a `pubspec.yaml`
/// file and whether it contains a Flutter SDK dependency.
Future<ProjectKind> inferProjectKind(
  String rootUri,
  FileSystem fileSystem,
) async {
  final pubspecFile = fileSystem
      .directory(Uri.parse(rootUri))
      .childFile('pubspec.yaml');
  if (!await pubspecFile.exists()) {
    return ProjectKind.unknown;
  }
  final pubspec = loadYaml(await pubspecFile.readAsString()) as Pubspec;

  if (pubspec.flutter != null ||
      pubspec.environment?.containsKey('flutter') == true ||
      pubspec.dependencies
          .followedBy(pubspec.devDependencies)
          .any((dep) => dep.sdk == 'flutter')) {
    return ProjectKind.flutter;
  }
  return ProjectKind.dart;
}

/// Runs a command in each of the project roots specified in the [request].
///
/// The [commandForRoot] function determines the executable to run (e.g., `dart`
/// or `flutter`), and it is combined with [arguments] to form the full command.
/// This command is then passed directly to [ProcessManager.run].
///
/// The [commandDescription] is used in the output to describe the command
/// being run. For example, if the command is `['dart', 'fix', '--apply']`, the
/// command description might be `dart fix`.
///
/// If no roots are provided in the [request], the command is run in all
/// [knownRoots]. Otherwise, all roots provided in the request must be
/// subdirectories of the [knownRoots].
///
/// [defaultPaths] can be specified for commands that require path arguments
/// (e.g., `dart format .`). These paths are used if the root configuration in
/// the [request] does not specify its own paths.
Future<CallToolResult> runCommandInRoots(
  CallToolRequest request, {
  FutureOr<String?> Function(String, FileSystem, Sdk) commandForRoot =
      defaultCommandForRoot,
  List<String> arguments = const [],
  required String commandDescription,
  required FileSystem fileSystem,
  required ProcessManager processManager,
  required List<Root> knownRoots,
  List<String> defaultPaths = const <String>[],
  required Sdk sdk,
}) async {
  var rootConfigs = (request.arguments?[ParameterNames.roots] as List?)
      ?.cast<Map<String, Object?>>();

  // Default to use the known roots if none were specified.
  if (rootConfigs == null || rootConfigs.isEmpty) {
    rootConfigs = [
      for (final root in knownRoots) {ParameterNames.root: root.uri},
    ];
  }

  final outputs = <Content>[];
  var isError = false;
  for (var rootConfig in rootConfigs) {
    final result = await runCommandInRoot(
      request,
      rootConfig: rootConfig,
      commandForRoot: commandForRoot,
      arguments: arguments,
      commandDescription: commandDescription,
      fileSystem: fileSystem,
      processManager: processManager,
      knownRoots: knownRoots,
      defaultPaths: defaultPaths,
      sdk: sdk,
    );
    isError = isError || result.isError == true;
    outputs.addAll(result.content);
  }
  return CallToolResult(content: outputs, isError: isError);
}

/// Runs a command in a single project root specified in the [request].
///
/// If [rootConfig] is provided, it is used to read the root configuration;
/// otherwise, the configuration is read directly from `request.arguments`.
///
/// The [commandForRoot] function determines the executable to run, which is
/// combined with [arguments] and passed to [ProcessManager.run].
///
/// The [commandDescription] is used in the output to describe the command being
/// run.
///
/// [defaultPaths] can be specified for commands that require path arguments and
/// are used if the root configuration does not provide its own paths.
Future<CallToolResult> runCommandInRoot(
  CallToolRequest request, {
  Map<String, Object?>? rootConfig,
  FutureOr<String?> Function(String, FileSystem, Sdk) commandForRoot =
      defaultCommandForRoot,
  List<String> arguments = const [],
  required String commandDescription,
  required FileSystem fileSystem,
  required ProcessManager processManager,
  required List<Root> knownRoots,
  List<String> defaultPaths = const <String>[],
  required Sdk sdk,
}) async {
  rootConfig ??= request.arguments;
  final rootUriString = rootConfig?[ParameterNames.root] as String?;
  if (rootUriString == null) {
    // This shouldn't happen based on the schema, but handle defensively.
    return CallToolResult(
      content: [
        TextContent(text: 'Invalid root configuration: missing `root` key.'),
      ],
      isError: true,
    )..failureReason ??= CallToolFailureReason.noRootGiven;
  }

  final root = knownRoots.firstWhereOrNull(
    (root) => _isUnderRoot(root, rootUriString, fileSystem),
  );
  if (root == null) {
    return CallToolResult(
      content: [
        TextContent(
          text:
              'Invalid root $rootUriString, must be under one of the '
              'registered project roots:\n\n${knownRoots.join('\n')}',
        ),
      ],
      isError: true,
    )..failureReason ??= CallToolFailureReason.invalidRootPath;
  }

  final rootUri = Uri.parse(rootUriString);
  if (rootUri.scheme != 'file') {
    return CallToolResult(
      content: [
        TextContent(
          text:
              'Only file scheme uris are allowed for roots, but got '
              '$rootUri',
        ),
      ],
      isError: true,
    )..failureReason ??= CallToolFailureReason.invalidRootScheme;
  }
  final projectRoot = fileSystem.directory(rootUri);

  final command = await commandForRoot(rootUriString, fileSystem, sdk);
  if (command == null) {
    return CallToolResult(
      content: [
        TextContent(
          text:
              'Flutter executable not found. Please ensure the Flutter SDK is in your path and restart the MCP server.',
        ),
      ],
      isError: true,
    );
  }

  final commandWithPaths = <String>[command, ...arguments];
  final paths =
      (rootConfig?[ParameterNames.paths] as List?)?.cast<String>() ??
      defaultPaths;
  final invalidPaths = paths.where(
    (path) => !_isUnderRoot(root, path, fileSystem),
  );
  if (invalidPaths.isNotEmpty) {
    return CallToolResult(
      content: [
        TextContent(
          text:
              'Paths are not allowed to escape their project root:\n'
              '${invalidPaths.join('\n')}',
        ),
      ],
      isError: true,
    )..failureReason ??= CallToolFailureReason.invalidPath;
  }
  commandWithPaths.addAll(paths);

  final workingDir = fileSystem.directory(projectRoot.path);
  await workingDir.create(recursive: true);

  final result = await processManager.run(
    commandWithPaths,
    workingDirectory: workingDir.path,
    runInShell:
        // Required when running .bat files on windows, but otherwise should
        // be avoided due to escaping behavior.
        io.Platform.isWindows && commandWithPaths.first.endsWith('.bat'),
  );

  final output = (result.stdout as String).trim();
  final errors = (result.stderr as String).trim();
  if (result.exitCode != 0) {
    return CallToolResult(
      content: [
        TextContent(
          text:
              '$commandDescription returned a non-zero exit code in '
              '${projectRoot.path}:\n'
              '$output${errors.isEmpty ? '' : '\nErrors:\n$errors'}',
        ),
        // Returning a non-zero exit code is not considered an "error" in the
        // "isError" sense.
      ],
    );
  }
  return CallToolResult(
    content: [
      TextContent(text: '$commandDescription in ${projectRoot.path}:\n$output'),
    ],
  );
}

/// Validates a root argument given via [rootConfig].
///
/// This function ensures that the root falls under one of the [knownRoots], and
/// that all `paths` arguments are also under the given root.
///
/// On success, it returns a record containing the validated [Root] and a list
/// of paths. If no [ParameterNames.paths] are provided, [defaultPaths] is used.
///
/// On failure, it returns a [CallToolResult] with an error message.
({Root? root, List<String>? paths, CallToolResult? errorResult})
validateRootConfig(
  Map<String, Object?>? rootConfig, {
  List<String>? defaultPaths,
  required FileSystem fileSystem,
  required List<Root> knownRoots,
}) {
  final rootUriString = rootConfig?[ParameterNames.root] as String?;
  if (rootUriString == null) {
    // This shouldn't happen based on the schema, but handle defensively.
    return (
      root: null,
      paths: null,
      errorResult: CallToolResult(
        content: [
          TextContent(text: 'Invalid root configuration: missing `root` key.'),
        ],
        isError: true,
      )..failureReason ??= CallToolFailureReason.noRootGiven,
    );
  }
  final rootUri = Uri.parse(rootUriString);
  if (rootUri.scheme != 'file') {
    return (
      root: null,
      paths: null,
      errorResult: CallToolResult(
        content: [
          TextContent(
            text:
                'Only file scheme uris are allowed for roots, but got '
                '$rootUri',
          ),
        ],
        isError: true,
      )..failureReason ??= CallToolFailureReason.invalidRootScheme,
    );
  }

  final knownRoot = knownRoots.firstWhereOrNull(
    (root) => _isUnderRoot(root, rootUriString, fileSystem),
  );
  if (knownRoot == null) {
    return (
      root: null,
      paths: null,
      errorResult: CallToolResult(
        content: [
          TextContent(
            text:
                'Invalid root $rootUriString, must be under one of the '
                'registered project roots:\n\n${knownRoots.join('\n')}',
          ),
        ],
        isError: true,
      )..failureReason ??= CallToolFailureReason.invalidRootPath,
    );
  }
  final root = Root(uri: rootUriString);

  final paths =
      (rootConfig?[ParameterNames.paths] as List?)?.cast<String>() ??
      defaultPaths;
  if (paths != null) {
    final invalidPaths = paths.where(
      (path) => !_isUnderRoot(root, path, fileSystem),
    );
    if (invalidPaths.isNotEmpty) {
      return (
        root: null,
        paths: null,
        errorResult: CallToolResult(
          content: [
            TextContent(
              text:
                  'Paths are not allowed to escape their project root:\n'
                  '${invalidPaths.join('\n')}',
            ),
          ],
          isError: true,
        )..failureReason ??= CallToolFailureReason.invalidPath,
      );
    }
  }
  return (root: root, paths: paths, errorResult: null);
}

/// Returns 'dart' or 'flutter' based on the pubspec contents.
///
/// Throws an [ArgumentError] if there is no pubspec.
Future<String?> defaultCommandForRoot(
  String rootUri,
  FileSystem fileSystem,
  Sdk sdk,
) async => switch (await inferProjectKind(rootUri, fileSystem)) {
  ProjectKind.dart => sdk.dartExecutablePath,
  ProjectKind.flutter => sdk.flutterExecutablePath,
  ProjectKind.unknown => throw ArgumentError.value(
    rootUri,
    'rootUri',
    'Unknown project kind at root $rootUri. All projects must have a '
        'pubspec.',
  ),
};

/// Returns whether [uri] is under or exactly equal to [root].
///
/// Relative uris will always be under [root] unless they escape it with `../`.
bool _isUnderRoot(Root root, String uri, FileSystem fileSystem) {
  // This normalizes the URI to ensure it is treated as a directory (for example
  // ensures it ends with a trailing slash).
  final rootUri = fileSystem.directory(Uri.parse(root.uri)).uri;
  final resolvedUri = rootUri.resolve(uri);
  // We don't care about queries or fragments, but the scheme/authority must
  // match.
  if (rootUri.scheme != resolvedUri.scheme ||
      rootUri.authority != resolvedUri.authority) {
    return false;
  }
  // Canonicalizing the paths handles any `../` segments and also deals with
  // trailing slashes versus no trailing slashes.

  final canonicalRootPath = fileSystem.path.canonicalize(rootUri.path);
  final canonicalUriPath = fileSystem.path.canonicalize(resolvedUri.path);
  return canonicalRootPath == canonicalUriPath ||
      fileSystem.path.isWithin(canonicalRootPath, canonicalUriPath);
}

/// The schema for the `roots` parameter for any tool that accepts it.
ListSchema rootsSchema({bool supportsPaths = false}) => Schema.list(
  title: 'The project roots to run this tool in.',
  items: Schema.object(
    properties: {
      ParameterNames.root: rootSchema,
      if (supportsPaths)
        ParameterNames.paths: Schema.list(
          title:
              'Paths to run this tool on. Must resolve to a path that is '
              'within the "root".',
          items: Schema.string(),
        ),
    },
    required: [ParameterNames.root],
  ),
);

/// The schema for a `root` parameter.
final rootSchema = Schema.string(
  title: 'The file URI of the project root to run this tool in.',
  description:
      'This must be equal to or a subdirectory of one of the roots '
      'allowed by the client. Must be a URI with a `file:` '
      'scheme (e.g. file:///absolute/path/to/root).',
);

/// A wrapper for a `pubspec.yaml` file, providing access to specific fields.
///
/// This extension type assumes a valid pubspec structure.
extension type Pubspec(Map<dynamic, dynamic> _value) {
  /// The `dependencies` section of the pubspec.
  Iterable<Dependency> get dependencies =>
      (_value['dependencies'] as Map<dynamic, dynamic>?)?.values
          .cast<Dependency>() ??
      [];

  /// The `dev_dependencies` section of the pubspec.
  Iterable<Dependency> get devDependencies =>
      (_value['dev_dependencies'] as Map<dynamic, dynamic>?)?.values
          .cast<Dependency>() ??
      [];

  /// The `environment` section of the pubspec.
  Map<dynamic, dynamic>? get environment =>
      _value['environment'] as Map<dynamic, dynamic>?;

  /// The `flutter` section of the pubspec.
  Map<dynamic, dynamic>? get flutter =>
      _value['flutter'] as Map<dynamic, dynamic>?;
}

/// A dependency entry in a `pubspec.yaml` file.
///
/// Dependencies can be represented as either a [String] (for version
/// constraints) or a [Map] (for more complex definitions like `sdk` or `path`).
extension type Dependency(Object? _value) {
  /// If this is an `sdk` dependency, returns the SDK name; otherwise, `null`.
  String? get sdk => _value is Map ? _value['sdk'] as String? : null;
}
