import 'package:dynamic_online_intl_manager/api/api.dart';
import 'package:dynamic_online_intl_manager/model/base_response.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Intl Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _currentLanguage;

  List<String> _languages = [];
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    Api api = Api();
    try {
      _languages = await api.getLanguages();
      if (_languages.isNotEmpty) {
        String lan = _languages.first;
        await _loadLanguage(lan);
      }
    } catch (e) {
      debugPrint(e.toString());
      return;
    }
  }

  Future<void> _loadLanguage(String language) async {
    Api api = Api();
    try {
      _translations = await api.getLanguageFile(language);
      if (!mounted) return;
      setState(() {
        _currentLanguage = language;
      });
    } catch (e) {
      debugPrint(e.toString());
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Intl Manager'),
        centerTitle: false,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              itemCount: _languages.length,
              itemBuilder: (ctx, idx) {
                String language = _languages[idx];
                return ListTile(
                  title: Text(language),
                  selectedTileColor: Colors.black12,
                  selected: _currentLanguage == language,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onTap: () => _loadLanguage(language),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 7,
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: ListView.builder(
                itemCount: _translations.entries.length,
                itemBuilder: (ctx, idx) {
                  String key = _translations.keys.elementAt(idx);
                  String value = _translations[key];
                  return ListTile(
                    title: Text(key),
                    subtitle: Text(value),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    trailing: const Icon(Icons.edit, size: 16),
                    onTap: () {
                      _showEditorDialog(key, value);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  late TextEditingController _controller;
  void _showEditorDialog(String key, String value) {
    _controller = TextEditingController(text: value);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(key),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _updateTranslation(key, _controller.text);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _updateTranslation(String key, String value) async {
    Api api = Api();
    CommonResponse res = await api.updateTranslation(_currentLanguage!, key, value);
    if (res.code == successCode) {
      _translations[key] = value;
      if (!mounted) return;
      setState(() {});
    } else {
      debugPrint('Failed to update translation: ${res.msg}');
    }
  }
}
