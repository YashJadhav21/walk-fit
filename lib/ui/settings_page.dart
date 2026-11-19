import 'package:flutter/material.dart';

import '../app_state.dart';
import '../gemini.dart';
import 'profile_form.dart';
import 'route_map.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _key = TextEditingController(text: AppState.instance.geminiKey);
  late final _mapKey = TextEditingController(text: AppState.instance.mapKey);
  bool _show = false;
  bool _testing = false;

  @override
  void dispose() {
    _key.dispose();
    _mapKey.dispose();
    super.dispose();
  }

  List<String> _models = [];
  String? _status;
  bool _statusOk = false;

  Future<void> _save() async {
    final k = _key.text.trim();
    FocusScope.of(context).unfocus();
    if (k.isEmpty) {
      await AppState.instance.setGeminiKey('');
      setState(() {
        _models = [];
        _status = null;
      });
      if (mounted) toast(context, 'Gemini key removed');
      return;
    }
    setState(() {
      _testing = true;
      _status = 'Checking key…';
      _statusOk = false;
    });
    try {
      final models = await Gemini.listModels(k, refresh: true);
      final foods = await Gemini.estimate(k, '1 roti',
          preferredModel: AppState.instance.geminiModel);
      await AppState.instance.setGeminiKey(k);
      if (!mounted) return;
      setState(() {
        _models = models;
        _statusOk = true;
        _status = 'Key works · ${Gemini.lastWorkingModel} · '
            '1 roti ≈ ${foods.first.kcal.round()} kcal';
      });
    } on GeminiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusOk = false;
        _status = e.message;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final k = AppState.instance.geminiKey;
    if (k.isNotEmpty) {
      Gemini.listModels(k).then((m) {
        if (mounted) setState(() => _models = m);
      }).catchError((_) {});
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
                  child: Text(_testing ? 'Checking key…' : 'Save & test key'),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(_statusOk ? Icons.check_circle : Icons.error_outline,
                        size: 18, color: _statusOk ? cs.onSurface : cs.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_status!,
                          style: t.bodySmall?.copyWith(
                              color: _statusOk ? cs.onSurface : cs.error)),
                    ),
                  ]),
                ],
                if (_models.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Label('Model'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _models.contains(AppState.instance.geminiModel)
                        ? AppState.instance.geminiModel
                        : '',
                    isExpanded: true,
                    decoration: fieldDeco(context, 'Gemini model'),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('Automatic (recommended)')),
                      for (final m in _models)
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: (v) => AppState.instance.setGeminiModel(v ?? ''),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Automatic picks the newest free Flash model your key can use '
                    'and switches if one hits its free limit.',
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SectionTitle('Map'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cartoKey.isNotEmpty
                      ? 'Using the black & white CARTO map.'
                      : 'Paste your free CARTO basemaps key (carto.com/basemaps/apikey) '
                          'for the black & white map. Without it, a greyscale '
                          'OpenStreetMap is used.',
                  style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mapKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: fieldDeco(context, 'CARTO key (optional)'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    await AppState.instance.setMapKey(_mapKey.text);
                    if (!context.mounted) return;
                    setState(() {});
                    toast(context, _mapKey.text.trim().isEmpty
                        ? 'Map key removed'
                        : 'Map key saved');
                  },
                  child: const Text('Save map key'),
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
          Text('Map data © OpenStreetMap contributors · CARTO.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
