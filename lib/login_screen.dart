import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sales_order_screen.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('rememberMe') ?? false;

    if (remember) {
      _userController.text = prefs.getString('savedUser') ?? '';
      _passwordController.text = prefs.getString('savedPassword') ?? '';
      setState(() => _rememberMe = true);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoggingIn = true);

    final prefs = await SharedPreferences.getInstance();

    final tenantId = prefs.getString('tenantId') ?? '';
    final clientId = prefs.getString('clientId') ?? '';
    final clientSecret = prefs.getString('clientSecret') ?? '';
    final resource = prefs.getString('resource') ?? '';
    final salesOrderEntity = prefs.getString('salesOrderEntity') ?? '';
    final salesLineEntity = prefs.getString('salesLineEntity') ?? '';

    if (tenantId.isEmpty ||
        clientId.isEmpty ||
        clientSecret.isEmpty ||
        resource.isEmpty ||
        salesOrderEntity.isEmpty ||
        salesLineEntity.isEmpty) {
      setState(() => _isLoggingIn = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Missing Settings'),
          content: Text('Please complete the settings before signing in.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (_rememberMe) {
      await prefs.setString('savedUser', _userController.text.trim());
      await prefs.setString('savedPassword', _passwordController.text.trim());
    } else {
      await prefs.remove('savedUser');
      await prefs.remove('savedPassword');
    }

    await prefs.setBool('rememberMe', _rememberMe);
    await prefs.setBool('loggedIn', true);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SalesOrderScreen(
          tenantId: tenantId,
          clientId: clientId,
          clientSecret: clientSecret,
          resource: resource,
          salesOrderEntity: salesOrderEntity,
          salesLineEntity: salesLineEntity,
        ),
      ),
    );

    setState(() => _isLoggingIn = false);
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        obscureText: obscure,
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
        actions: [],
        leading: IconButton(
          icon: Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen()),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildField(_userController, 'User Account'),
              _buildField(_passwordController, 'Password', obscure: true),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (val) =>
                        setState(() => _rememberMe = val ?? false),
                  ),
                  Text('Remember me'),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoggingIn ? null : _login,
                child: _isLoggingIn
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
