import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'create_sales_line_screen.dart';
import 'd365_service.dart';

class NewSalesOrderScreen extends StatefulWidget {
  final String accessToken;
  final String tenantId;
  final String clientId;
  final String clientSecret;
  final String resource;

  const NewSalesOrderScreen({
    Key? key,
    required this.accessToken,
    required this.tenantId,
    required this.clientId,
    required this.clientSecret,
    required this.resource,
  }) : super(key: key);

  @override
  State<NewSalesOrderScreen> createState() => _NewSalesOrderScreenState();
}

class _NewSalesOrderScreenState extends State<NewSalesOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _warehouseController = TextEditingController();
  final _siteController = TextEditingController();
  final _currencyController = TextEditingController();

  bool _isSubmitting = false;
  List<String> _customers = [];
  String? _selectedCustomer;

  String? tenantId, clientId, clientSecret, resource;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndCustomers();
  }

  Future<void> _loadSettingsAndCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    tenantId = prefs.getString('tenantId');
    clientId = prefs.getString('clientId');
    clientSecret = prefs.getString('clientSecret');
    resource = prefs.getString('resource');

    if ([tenantId, clientId, clientSecret, resource].contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Missing settings. Please check app settings.'),
        ),
      );
      Navigator.pop(context);
      return;
    }

    final service = D365Service(
      tenantId: tenantId!,
      clientId: clientId!,
      clientSecret: clientSecret!,
      resource: resource!,
    );

    try {
      final customers = await service.getCustomers(widget.accessToken);
      setState(() {
        _customers = customers;
        if (customers.isNotEmpty) _selectedCustomer = customers.first;
      });
    } catch (e) {
      print('❌ Failed to fetch customers: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading customers: $e')));
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final orderData = {
      "dataAreaId": "usmf",
      "SalesOrderName": "Contoso Europe",
      "CurrencyCode": _currencyController.text.trim(),
      "InvoiceCustomerAccountNumber": _selectedCustomer,
      "OrderingCustomerAccountNumber": _selectedCustomer,
      "LanguageId": "en-us",
      "DefaultShippingWarehouseId": _warehouseController.text.trim(),
      "DefaultShippingSiteId": _siteController.text.trim(),
    };

    final service = D365Service(
      tenantId: tenantId!,
      clientId: clientId!,
      clientSecret: clientSecret!,
      resource: resource!,
    );

    try {
      final salesOrderNumber = await service.createSalesOrder(
        widget.accessToken,
        orderData,
      );
      if (salesOrderNumber != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CreateSalesLineScreen(
              salesOrderNumber: salesOrderNumber,
              accessToken: widget.accessToken,
              tenantId: tenantId!,
              clientId: clientId!,
              clientSecret: clientSecret!,
              resource: resource!,
              orderFields: orderData,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to create sales order')),
        );
      }
    } catch (e) {
      print('❌ Exception while creating order: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New Sales Order')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCustomer,
                decoration: InputDecoration(labelText: 'Select Customer'),
                items: _customers
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCustomer = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
              SizedBox(height: 12),
              _buildField(_warehouseController, 'Warehouse ID'),
              _buildField(_siteController, 'Site ID'),
              _buildField(_currencyController, 'Currency'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _createOrder,
                child: _isSubmitting
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Create Order'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
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
}
