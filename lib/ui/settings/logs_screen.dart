import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/fox_log.dart';
import '../theme/tokens.dart';

const _clipboardChannel = MethodChannel('foxyco/clipboard');
Timer? _fallbackClipboardTimer;

Uri logEmailUri(String logs) => Uri(
  scheme: 'mailto',
  path: 'foxyco.dev@gmail.com',
  queryParameters: {'subject': 'FoxyCo diagnostic logs', 'body': logs},
);

Future<void> _setFallbackClipboard(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  _fallbackClipboardTimer?.cancel();
  _fallbackClipboardTimer = Timer(const Duration(minutes: 1), () async {
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == text) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  });
}

Future<void> setSensitiveClipboard(String text) async {
  try {
    await _clipboardChannel.invokeMethod<void>('setSensitiveText', {
      'text': text,
    });
  } on MissingPluginException {
    await _setFallbackClipboard(text);
  } on PlatformException {
    await _setFallbackClipboard(text);
  }
}

/// Scrollable tail of the persistent log (spec M5 §2). Newest at bottom;
/// copy-to-clipboard export (no share dep) and a confirm-gated Clear.
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  String _tail = '';
  bool _loaded = false;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final tail = await ref.read(foxLogProvider).tail();
    if (!mounted) return;
    setState(() {
      _tail = tail;
      _loaded = true;
    });
    // Newest lines live at the bottom — jump there after layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _copy() async {
    final copied = _tail;
    await setSensitiveClipboard(copied);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sensitive logs copied — clipboard clears in 1 minute'),
      ),
    );
  }

  Future<void> _email() async {
    try {
      if (await launchUrl(
        logEmailUri(_tail),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No email app is available')));
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear logs?'),
        content: const Text('Deletes both log files. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(foxLogProvider).clear();
    await _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic logs'),
        actions: [
          IconButton(
            key: const ValueKey('email-logs'),
            icon: const Icon(Icons.email_outlined),
            tooltip: 'Email logs to FoxyCo support',
            onPressed: _tail.isEmpty ? null : _email,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy to clipboard',
            onPressed: _tail.isEmpty ? null : _copy,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear logs',
            onPressed: _clear,
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _tail.isEmpty
          ? const Center(child: Text('No logs yet'))
          : SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.all(Gap.md),
              child: SelectableText(
                _tail,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
              ),
            ),
    );
  }
}
