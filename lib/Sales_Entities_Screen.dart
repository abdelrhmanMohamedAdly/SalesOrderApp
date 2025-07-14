import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SalesEntitiesScreen extends StatefulWidget {
  @override
  _SalesEntitiesScreenState createState() => _SalesEntitiesScreenState();
}

class _SalesEntitiesScreenState extends State<SalesEntitiesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _salesOrderController = TextEditingController();
  final _salesLineController = TextEditingController();
  final _customersController = TextEditingController();
  final _itemController = TextEditingController();
  final _warehouseController = TextEditingController();
  final _siteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  Future<void> _loadEntities() async {
    final prefs = await SharedPreferences.getInstance();
    _salesOrderController.text = prefs.getString('salesOrderEntity') ?? '';
    _salesLineController.text = prefs.getString('salesLineEntity') ?? '';
    _customersController.text = prefs.getString('allCustomersEntity') ?? '';
    _itemController.text = prefs.getString('itemEntity') ?? '';
    _warehouseController.text = prefs.getString('warehouseEntity') ?? '';
    _siteController.text = prefs.getString('siteEntity') ?? '';
  }

  Future<void> _saveEntities() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'salesOrderEntity',
      _salesOrderController.text.trim(),
    );
    await prefs.setString('salesLineEntity', _salesLineController.text.trim());
    await prefs.setString(
      'allCustomersEntity',
      _customersController.text.trim(),
    );
    await prefs.setString('itemEntity', _itemController.text.trim());
    await prefs.setString('warehouseEntity', _warehouseController.text.trim());
    await prefs.setString('siteEntity', _siteController.text.trim());

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('✅ Entities saved successfully')));
    Navigator.pop(context);
  }

  Widget _buildField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
      appBar: AppBar(title: Text('Sales Entities')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildField(_salesOrderController, 'Sales Order Entity'),
              _buildField(_salesLineController, 'Sales Line Entity'),
              _buildField(_customersController, 'All Customers Entity'),
              _buildField(_itemController, 'Item Entity'),
              _buildField(_warehouseController, 'Warehouse Entity'),
              _buildField(_siteController, 'Site Entity'),
              SizedBox(height: 20),
              ElevatedButton(onPressed: _saveEntities, child: Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
