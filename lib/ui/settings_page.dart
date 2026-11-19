import 'package:flutter/material.dart';

import '../app_state.dart';
import '../gemini.dart';
import 'profile_form.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _key = TextEditingController(text: AppState.instance.geminiKey);
  bool _show = false;
  bool _testing = false;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final k = _key.text.trim();
    if (k.isEmpty) {
      await AppState.instance.setGeminiKey('');
      if (mounted) toast(context, 'Gemini key removed');
      return;
    }
    setState(() => _testing = true);
    try {
      await Gemini.estimate(k, '1 roti');
      await AppState.instance.setGeminiKey(k);
      if (mounted) {
        toast(context, 'Key works. Saved.');
        FocusScope.of(context).unfocus();
      }
    } on GeminiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const SectionTitle('Profile'),
          Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Edit profile and goal'),
              subtitle: const Text('Age, height, weight, activity, pace'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileFormPage())),
            ),
          ),
          const SectionTitle('Gemini food estimates (optional)'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Used only for foods that are not in the built-in list. '
                  'Get a free key at aistudio.google.com → Get API key, then paste it here. '
                  'The key is stored only on this phone.',
                  style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _key,
                  obscureText: !_show,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: fieldDeco(context, 'Gemini API key').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _show = !_show),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: _testing ? null : _save,
                  child: Text(_testing ? 'Checking key…' : 'Save key'),
                ),
              ],
            ),
          ),
          const SectionTitle('Walk tracking'),
          Panel(
            child: Text(
              'GPS starts only when you tap Start and stops on Pause or Stop. '
              'While a walk is running you will see a "Walk in progress" notification. '
              'If tracking stops when the screen is off, open Android Settings → Apps → WalkFit → '
              'Battery and choose "Unrestricted".',
              style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SectionTitle('Data'),
          Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: cs.error),
              title: Text('Erase all data', style: TextStyle(color: cs.error)),
              subtitle: const Text('Profile, walks, food log and weights'),
              onTap: () async {
                final nav = Navigator.of(context);
                final ok = await confirm(context, 'Erase everything?',
                    'This cannot be undone.',
                    ok: 'Erase', destructive: true);
                if (!ok) return;
                await AppState.instance.resetAll();
                nav.popUntil((r) => r.isFirst);
              },
            ),
          ),
          const SizedBox(height: 16),
          Text('Map data © OpenStreetMap contributors.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
