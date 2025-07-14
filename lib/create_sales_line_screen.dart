import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'd365_service.dart';
import 'sales_order_lines_screen.dart';

class CreateSalesLineScreen extends StatefulWidget {
  final String salesOrderNumber;
  final Map<String, dynamic> orderFields;
  final String accessToken;
  final String tenantId;
  final String clientId;
  final String clientSecret;
  final String resource;

  const CreateSalesLineScreen({
    required this.salesOrderNumber,
    required this.orderFields,
    required this.accessToken,
    required this.tenantId,
    required this.clientId,
    required this.clientSecret,
    required this.resource,
  });

  @override
  State<CreateSalesLineScreen> createState() => _CreateSalesLineScreenState();
}

class _CreateSalesLineScreenState extends State<CreateSalesLineScreen> {
  final _formKey = GlobalKey<FormState>();

  List<String> _items = [];
  List<Map<String, String>> _warehouses = [];
  List<String> _sites = [];
  List<String> _currencies = ['USD', 'EUR', 'GBP', 'EGP', 'SAR', 'AED'];

  String? _selectedItem;
  String? _selectedCurrency;
  final _quantityController = TextEditingController();
  final _discountController = TextEditingController();
  final _priceController = TextEditingController();

  bool _isSubmitting = false;
  String? salesLineEntity;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndMetadata();
  }

  Future<void> _loadSettingsAndMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    salesLineEntity = prefs.getString('salesLineEntity') ?? '';
    if (salesLineEntity!.isEmpty) {
      _showErrorAndPop('Sales Line Entity not set. Check settings.');
      return;
    }

    final service = D365Service(
      tenantId: widget.tenantId,
      clientId: widget.clientId,
      clientSecret: widget.clientSecret,
      resource: widget.resource,
    );

    try {
      final items = await service.getItems(widget.accessToken);

      setState(() {
        _items = items;
        if (_items.isNotEmpty) _selectedItem = _items.first
            .split(' - ')
            .first;
        if (_currencies.isNotEmpty) _selectedCurrency = _currencies.first;
      });
    } catch (e) {
      _showErrorAndPop('Error loading metadata: $e');
    }
  }

  void _showErrorAndPop(String msg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.pop(context);
    });
  }

  Future<void> _createLine() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final lineData = {
      "dataAreaId": "usmf",
      "SalesOrderNumber": widget.salesOrderNumber,
      "ItemNumber": _selectedItem,
      "OrderedSalesQuantity": double.tryParse(
          _quantityController.text.trim()) ?? 1.0,
      "SalesPrice": double.tryParse(_priceController.text.trim()) ?? 0.0,
      "SalesPriceQuantity": 1.0,
      "LineDiscountAmount": double.tryParse(_discountController.text.trim()) ??
          0.0,
      "ShippingWarehouseId": widget.orderFields["DefaultShippingWarehouseId"],
      "ShippingSiteId": widget.orderFields["DefaultShippingSiteId"],
      "CurrencyCode": _selectedCurrency,
    };

    final url = '${widget.resource}/data/$salesLineEntity';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(lineData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Sales line created successfully')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SalesOrderLinesScreen(
                  orderNumber: widget.salesOrderNumber,
                  accessToken: widget.accessToken,
                  tenantId: widget.tenantId,
                  clientId: widget.clientId,
                  clientSecret: widget.clientSecret,
                  resource: widget.resource,
                  orderFields: widget.orderFields,
                  forceReload: true,
                ),
          ),
        );
      } else {
        throw Exception('Failed with status ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Exception: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Widget _buildDropdown({
    required String label,
    required List<dynamic> items,
    required dynamic selectedValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    dynamic resolvedValue = selectedValue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField(
        isExpanded: true,
        value: resolvedValue,
        decoration: InputDecoration(
            labelText: label, border: OutlineInputBorder()),
        items: items.map<DropdownMenuItem>((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (v) =>
        v == null || (v is String && v.isEmpty)
            ? 'Required'
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Line: ${widget.salesOrderNumber}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildDropdown(
                label: 'Item',
                items: _items,
                selectedValue: _selectedItem,
                onChanged: (val) =>
                    setState(() =>
                    _selectedItem = val
                        ?.split(' - ')
                        .first),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                    labelText: 'Quantity', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                initialValue: widget
                    .orderFields["DefaultShippingWarehouseId"] ?? '',
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Warehouse',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextFormField(
                initialValue: widget.orderFields["DefaultShippingSiteId"] ?? '',
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Site',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                    labelText: 'Price', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _discountController,
                decoration: InputDecoration(
                    labelText: 'Discount', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),
              _buildDropdown(
                label: 'Currency Code',
                items: _currencies,
                selectedValue: _selectedCurrency,
                onChanged: (val) => setState(() => _selectedCurrency = val),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _createLine,
                child: _isSubmitting
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Add Line'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
