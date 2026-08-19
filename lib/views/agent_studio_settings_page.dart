import 'package:flutter/material.dart';

import '../agent_studio/agent_studio_client.dart';
import '../agent_studio/agent_studio_config.dart';

class AgentStudioSettingsPage extends StatefulWidget {
  const AgentStudioSettingsPage({super.key});

  @override
  State<AgentStudioSettingsPage> createState() =>
      _AgentStudioSettingsPageState();
}

class _AgentStudioSettingsPageState extends State<AgentStudioSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _projectController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _obscureToken = true;
  String _deviceId = '';
  String? _status;
  bool? _connectionHealthy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await AgentStudioConfigStore.instance.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _baseUrlController.text = config.baseUrl;
      _tokenController.text = config.deviceToken;
      _projectController.text = config.projectId ?? '';
      _deviceId = config.deviceId;
      _loading = false;
    });
  }

  Future<void> _save({bool testAfterSave = false}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _status = null;
      _connectionHealthy = null;
    });

    try {
      final config = AgentStudioConfig(
        baseUrl: _baseUrlController.text,
        deviceToken: _tokenController.text,
        deviceId: _deviceId,
        projectId: _projectController.text.trim().isEmpty
            ? null
            : _projectController.text.trim(),
      );
      await AgentStudioConfigStore.instance.save(config);

      var healthy = true;
      if (testAfterSave) {
        healthy = await AgentStudioClient.instance.healthCheck();
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _connectionHealthy = testAfterSave ? healthy : null;
        _status = testAfterSave
            ? healthy
                ? 'Connected to Agent Studio.'
                : 'Saved, but the health check failed.'
            : 'Agent Studio settings saved.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionHealthy = false;
        _status = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent Studio')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Connect the G1 companion directly to your private Agent Studio gateway. Use an HTTPS Tailscale address or another authenticated private endpoint.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _baseUrlController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(
                        labelText: 'Agent Studio URL',
                        hintText: 'https://agent-studio.example.ts.net',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final uri = Uri.tryParse(value?.trim() ?? '');
                        if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                          return 'Enter a complete URL.';
                        }
                        if (uri.scheme != 'https' && uri.scheme != 'http') {
                          return 'Use HTTPS or HTTP.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tokenController,
                      obscureText: _obscureToken,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Paired device token',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureToken
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                            () => _obscureToken = !_obscureToken,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter the token issued by Agent Studio.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _projectController,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Default project ID, optional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      'Device ID: $_deviceId',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(testAfterSave: true),
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link),
                      label: const Text('Save and test'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Save without testing'),
                    ),
                    if (_status != null) ...[
                      const SizedBox(height: 20),
                      Card(
                        child: ListTile(
                          leading: Icon(
                            _connectionHealthy == true
                                ? Icons.check_circle
                                : _connectionHealthy == false
                                    ? Icons.error
                                    : Icons.info,
                          ),
                          title: Text(_status!),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      'The device token is stored in the iOS Keychain or the platform secure-storage equivalent. It is never written to source code or included in G1 display output.',
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    _projectController.dispose();
    super.dispose();
  }
}
