import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onSettingsSaved;

  const SettingsScreen({Key? key, this.onSettingsSaved}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenantIdController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _resourceController = TextEditingController();

  bool _rememberSettings = false;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('rememberSettings') ?? false;

    if (remember) {
      _tenantIdController.text = prefs.getString('tenantId') ?? '';
      _clientIdController.text = prefs.getString('clientId') ?? '';
      _clientSecretController.text = prefs.getString('clientSecret') ?? '';
      _resourceController.text = prefs.getString('resource') ?? '';
      setState(() => _rememberSettings = true);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();

    if (_rememberSettings) {
      await prefs.setString('tenantId', _tenantIdController.text.trim());
      await prefs.setString('clientId', _clientIdController.text.trim());
      await prefs.setString(
          'clientSecret', _clientSecretController.text.trim());
      await prefs.setString('resource', _resourceController.text.trim());
    }

    await prefs.setBool('settingsCompleted', true);
    await prefs.setBool('rememberSettings', _rememberSettings);

    if (widget.onSettingsSaved != null) {
      widget.onSettingsSaved!();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  Widget _buildField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('App Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildField(_tenantIdController, 'Tenant ID'),
              _buildField(_clientIdController, 'Client ID'),
              _buildField(_clientSecretController, 'Client Secret'),
              _buildField(_resourceController, 'Resource'),
              Row(
                children: [
                  Checkbox(
                    value: _rememberSettings,
                    onChanged: (val) =>
                        setState(() => _rememberSettings = val ?? false),
                  ),
                  Text("Remember Settings"),
                ],
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveSettings,
                child: Text('Save Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
