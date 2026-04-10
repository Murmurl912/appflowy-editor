import 'package:example/pages/document_list_page.dart';
import 'package:example/providers/document_list_provider.dart';
import 'package:example/repo/document_repository.dart';
import 'package:example/repo/in_memory_document_repository.dart';
import 'package:example/services/mermaid_renderer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.android) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // Initialize native Mermaid renderer (silently fails if lib not available)
  final mermaidOk = MermaidRenderer.init();
  debugPrint('MermaidRenderer: ${mermaidOk ? "loaded" : "not available"}');

  final initialFilePath = await _getInitialFilePath();
  final repo = InMemoryDocumentRepository();

  runApp(App(repo: repo, initialFilePath: initialFilePath));
}

Future<String?> _getInitialFilePath() async {
  try {
    const channel = MethodChannel('app.channel.shared.data');
    final path = await channel.invokeMethod<String>('getSharedFile');
    return path;
  } catch (_) {
    return null;
  }
}

class App extends StatelessWidget {
  const App({super.key, required this.repo, this.initialFilePath});

  final DocumentRepository repo;
  final String? initialFilePath;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DocumentRepository>.value(value: repo),
        ChangeNotifierProvider(
          create: (_) => DocumentListProvider(repo),
        ),
      ],
      child: MaterialApp(
        title: 'Markdown Editor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 1,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            onPrimary: Colors.black,
            surface: Colors.black,
            onSurface: Colors.white,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 1,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
        ),
        home: DocumentListPage(initialFilePath: initialFilePath),
      ),
    );
  }
}
