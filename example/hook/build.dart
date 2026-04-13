import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    // Build web assets (TipTap + Vditor) before native code assets.
    // These are Flutter data assets that must exist in assets/ before bundling.
    await _buildWebAssets(input);

    if (!input.config.buildCodeAssets) return;
    await const RustBuilder(
      assetName: 'mermaid_ffi',
      cratePath: 'rust',
    ).run(input: input, output: output);
  });
}

/// Build TipTap and Vditor web bundles if sources are newer than outputs.
Future<void> _buildWebAssets(BuildInput input) async {
  final packageRoot = input.packageRoot.toFilePath();

  await _buildTiptap(packageRoot);
  await _buildVditor(packageRoot);
}

/// Build TipTap: npm install (if needed) + esbuild + copy to assets.
Future<void> _buildTiptap(String packageRoot) async {
  final tiptapDir = Directory('$packageRoot/tiptap');
  if (!tiptapDir.existsSync()) {
    _log('TipTap source not found, skipping.');
    return;
  }

  final outputJs = File('$packageRoot/assets/web/tiptap/tiptap-bundle.js');
  final srcIndex = File('$packageRoot/tiptap/src/index.ts');

  // Skip if output exists and is newer than all source files
  if (outputJs.existsSync() && srcIndex.existsSync()) {
    final srcFiles = Directory('$packageRoot/tiptap/src')
        .listSync(recursive: true)
        .whereType<File>();
    final outputMod = outputJs.lastModifiedSync();
    final needsBuild = srcFiles.any(
      (f) => f.lastModifiedSync().isAfter(outputMod),
    );
    if (!needsBuild) {
      _log('TipTap: up to date, skipping build.');
      return;
    }
  }

  _log('TipTap: building...');

  // npm install if node_modules missing
  final nodeModules = Directory('$packageRoot/tiptap/node_modules');
  if (!nodeModules.existsSync()) {
    _log('TipTap: installing npm dependencies...');
    final npmResult = await Process.run(
      'npm',
      ['install'],
      workingDirectory: '$packageRoot/tiptap',
      environment: _npmEnv(),
    );
    if (npmResult.exitCode != 0) {
      _log('TipTap npm install failed: ${npmResult.stderr}');
      return;
    }
  }

  // esbuild
  final buildResult = await Process.run(
    'npx',
    [
      'esbuild',
      'src/index.ts',
      '--bundle',
      '--minify',
      '--outfile=dist/tiptap-bundle.js',
      '--format=iife',
      '--global-name=TiptapEditor',
      '--target=es2020',
    ],
    workingDirectory: '$packageRoot/tiptap',
    environment: _npmEnv(),
  );
  if (buildResult.exitCode != 0) {
    _log('TipTap esbuild failed: ${buildResult.stderr}');
    return;
  }

  // Copy CSS
  final srcCss = File('$packageRoot/tiptap/src/style.css');
  final distCss = File('$packageRoot/tiptap/dist/tiptap.css');
  if (srcCss.existsSync()) {
    srcCss.copySync(distCss.path);
  }

  // Copy to Flutter assets
  final assetsDir = Directory('$packageRoot/assets/web/tiptap');
  if (!assetsDir.existsSync()) {
    assetsDir.createSync(recursive: true);
  }
  File('$packageRoot/tiptap/dist/tiptap-bundle.js')
      .copySync('$packageRoot/assets/web/tiptap/tiptap-bundle.js');
  if (distCss.existsSync()) {
    distCss.copySync('$packageRoot/assets/web/tiptap/tiptap.css');
  }

  // Copy KaTeX CSS + fonts
  final katexCss = File('$packageRoot/tiptap/node_modules/katex/dist/katex.min.css');
  if (katexCss.existsSync()) {
    katexCss.copySync('$packageRoot/assets/web/tiptap/katex.min.css');
  }
  final katexFontsDir = Directory('$packageRoot/tiptap/node_modules/katex/dist/fonts');
  final targetFontsDir = Directory('$packageRoot/assets/web/tiptap/fonts');
  if (katexFontsDir.existsSync()) {
    if (!targetFontsDir.existsSync()) targetFontsDir.createSync(recursive: true);
    for (final f in katexFontsDir.listSync().whereType<File>()) {
      if (f.path.endsWith('.woff2')) {
        f.copySync('${targetFontsDir.path}/${f.uri.pathSegments.last}');
      }
    }
  }

  _log('TipTap: build complete.');
}

/// Build Vditor: pnpm build + copy dist to assets (if sources changed).
Future<void> _buildVditor(String packageRoot) async {
  final vditorDir = Directory('$packageRoot/vditor');
  if (!vditorDir.existsSync()) {
    _log('Vditor source not found, skipping.');
    return;
  }

  final outputIndex = File('$packageRoot/assets/web/vditor/dist/index.min.js');
  final srcBridge = File('$packageRoot/vditor/src/ts/bridge.ts');

  // Skip if output exists and is newer than bridge.ts (main custom file)
  if (outputIndex.existsSync() && srcBridge.existsSync()) {
    final outputMod = outputIndex.lastModifiedSync();
    // Check bridge.ts and index.ts as the main custom files
    final srcFiles = [
      srcBridge,
      File('$packageRoot/vditor/src/index.ts'),
    ].where((f) => f.existsSync());
    final needsBuild = srcFiles.any(
      (f) => f.lastModifiedSync().isAfter(outputMod),
    );
    if (!needsBuild) {
      _log('Vditor: up to date, skipping build.');
      return;
    }
  }

  _log('Vditor: building...');

  // Check if pnpm node_modules exist
  final nodeModules = Directory('$packageRoot/vditor/node_modules');
  if (!nodeModules.existsSync()) {
    _log('Vditor: installing pnpm dependencies...');
    final pnpmResult = await Process.run(
      'pnpm',
      ['install'],
      workingDirectory: '$packageRoot/vditor',
      environment: _npmEnv(),
    );
    if (pnpmResult.exitCode != 0) {
      _log('Vditor pnpm install failed: ${pnpmResult.stderr}');
      return;
    }
  }

  // pnpm build
  final buildResult = await Process.run(
    'pnpm',
    ['run', 'build'],
    workingDirectory: '$packageRoot/vditor',
    environment: _npmEnv(),
  );
  if (buildResult.exitCode != 0) {
    _log('Vditor build failed: ${buildResult.stderr}');
    return;
  }

  // Copy dist to assets (clean first)
  final assetsDir = Directory('$packageRoot/assets/web/vditor/dist');
  if (assetsDir.existsSync()) {
    assetsDir.deleteSync(recursive: true);
  }

  // Copy recursively
  await _copyDirectory(
    Directory('$packageRoot/vditor/dist'),
    assetsDir,
  );

  // Remove unused large modules
  final jsDir = Directory('$packageRoot/assets/web/vditor/dist/js');
  if (jsDir.existsSync()) {
    for (final name in [
      'echarts', 'graphviz', 'plantuml', 'abcjs',
      'flowchart.js', 'markmap', 'mathjax', 'smiles-drawer',
    ]) {
      final dir = Directory('${jsDir.path}/$name');
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
  }

  _log('Vditor: build complete.');
}

/// Recursively copy a directory.
Future<void> _copyDirectory(Directory source, Directory destination) async {
  if (!destination.existsSync()) {
    destination.createSync(recursive: true);
  }
  await for (final entity in source.list(recursive: false)) {
    final newPath =
        '${destination.path}/${entity.uri.pathSegments.last}';
    if (entity is File) {
      entity.copySync(newPath);
    } else if (entity is Directory) {
      await _copyDirectory(entity, Directory(newPath));
    }
  }
}

/// Get environment with PATH for npm/pnpm/npx commands.
Map<String, String> _npmEnv() {
  final env = Map<String, String>.from(Platform.environment);
  // Ensure common Node.js paths are in PATH
  final extra = [
    '/usr/local/bin',
    '/opt/homebrew/bin',
    '${Platform.environment['HOME']}/.nvm/versions/node/current/bin',
    '${Platform.environment['HOME']}/.volta/bin',
    '${Platform.environment['HOME']}/.fnm/aliases/default/bin',
  ];
  final path = env['PATH'] ?? '';
  env['PATH'] = '${extra.join(':')}:$path';
  return env;
}

void _log(String message) {
  // ignore: avoid_print
  print('[WebAssets] $message');
}
