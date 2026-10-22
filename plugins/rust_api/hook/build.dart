import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.userDefines['build_assets'] == false) {
      stdout.writeln('Skipping the Rust build: user-define build_assets=false');
      return;
    }
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      extraCargoEnvironmentVariables: _bindgenEnvironment(input),
    ).run(input: input, output: output);
  });
}

// rquickjs runs bindgen on Android. bindgen loads libclang in-process, and a
// libclang loaded from LIBCLANG_PATH cannot derive its builtin-header
// directory (InstalledDir comes out empty), so parsing failed on <stdarg.h>
// and friends. Point bindgen at a matching libclang and pass an explicit
// -resource-dir plus the NDK sysroot so both the builtin clang headers and
// the bionic headers resolve.
Map<String, String> _bindgenEnvironment(BuildInput input) {
  if (!input.config.buildCodeAssets ||
      input.config.code.targetOS != OS.android) {
    return const {};
  }
  final compiler = input.config.code.cCompiler?.compiler;
  if (compiler == null) {
    return const {};
  }
  final libclangDir = _libclangDirectory(compiler);
  final resourceDir = _resourceDirectory(libclangDir);
  if (resourceDir == null) {
    throw StateError(
      'No clang resource headers (include/stdarg.h) found for the libclang '
      'in ${libclangDir.path}; set VYRAX_LIBCLANG_RESOURCE_DIR',
    );
  }
  final targetTriple = switch (input.config.code.targetArchitecture) {
    Architecture.arm64 => 'aarch64-linux-android',
    Architecture.arm => 'armv7-linux-androideabi',
    Architecture.x64 => 'x86_64-linux-android',
    _ => throw StateError(
      'Unsupported Android architecture: '
      '${input.config.code.targetArchitecture}',
    ),
  };
  final sysrootTriple = switch (targetTriple) {
    'armv7-linux-androideabi' => 'arm-linux-androideabi',
    _ => targetTriple,
  };
  final toolchainRoot = File.fromUri(compiler).parent.parent.path;
  final sysroot = _normalize('$toolchainRoot/sysroot');
  final bindgenArgs = [
    '--sysroot=$sysroot',
    '-I$sysroot/usr/include/$sysrootTriple',
    '-resource-dir=${_normalize(resourceDir.path)}',
  ].join(' ');
  return {
    'LIBCLANG_PATH': libclangDir.path,
    'BINDGEN_EXTRA_CLANG_ARGS_${targetTriple.replaceAll('-', '_')}':
        bindgenArgs,
  };
}

String _normalize(String path) => path.replaceAll(r'\', '/');

Directory _libclangDirectory(Uri compiler) {
  // hooks_runner forwards only a whitelist of environment variables to hook
  // processes (PATH, ANDROID_HOME, LIBCLANG_PATH, ...), so custom names such
  // as VYRAX_LIBCLANG_PATH never arrive; LIBCLANG_PATH does.
  for (final name in const ['VYRAX_LIBCLANG_PATH', 'LIBCLANG_PATH']) {
    final override = Platform.environment[name];
    if (override != null && override.isNotEmpty) {
      final directory = Directory(override);
      if (directory.existsSync() && directory.listSync().any(_isLibclang)) {
        return directory;
      }
    }
  }
  // Linux NDKs before r26 keep libclang under lib64, later ones and every
  // macOS NDK under lib.
  final llvmRoot = File.fromUri(compiler).parent.parent;
  for (final name in const ['lib', 'lib64', 'bin']) {
    final directory = Directory(
      '${llvmRoot.path}${Platform.pathSeparator}$name',
    );
    if (directory.existsSync() && directory.listSync().any(_isLibclang)) {
      return directory;
    }
  }
  throw StateError(
    'No libclang under ${llvmRoot.path} (lib, lib64 or bin); the NDK Flutter '
    'passed cannot run bindgen for rquickjs',
  );
}

Directory? _resourceDirectory(Directory libclangDir) {
  final override = Platform.environment['VYRAX_LIBCLANG_RESOURCE_DIR'];
  if (override != null && override.isNotEmpty) {
    final directory = Directory(override);
    if (_hasBuiltinHeaders(directory)) {
      return directory;
    }
  }
  // libclangDir is <llvm-root>/bin or <llvm-root>/lib; the matching resource
  // directory lives at <llvm-root>/lib/clang/<version>.
  final clangRoot = Directory(
    '${libclangDir.parent.path}${Platform.pathSeparator}lib'
    '${Platform.pathSeparator}clang',
  );
  if (clangRoot.existsSync()) {
    for (final entity in clangRoot.listSync()) {
      if (entity is Directory && _hasBuiltinHeaders(entity)) {
        return entity;
      }
    }
  }
  return null;
}

bool _hasBuiltinHeaders(Directory resourceDir) {
  final include = Directory(
    '${resourceDir.path}${Platform.pathSeparator}include',
  );
  return include.existsSync() &&
      File('${include.path}${Platform.pathSeparator}stdarg.h').existsSync();
}

bool _isLibclang(FileSystemEntity entity) {
  return entity.path.split(Platform.pathSeparator).last.startsWith('libclang.');
}
