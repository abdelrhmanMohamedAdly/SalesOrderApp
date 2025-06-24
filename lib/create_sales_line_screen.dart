import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  final _itemIdController = TextEditingController();
  final _quantityController = TextEditingController();
  final _discountController = TextEditingController();
  final _shippingWarehouseController = TextEditingController();
  final _siteController = TextEditingController();
  final _priceController = TextEditingController();
  final _currencyController = TextEditingController(text: 'USD');

  bool _isSubmitting = false;

  String? salesLineEntity;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    salesLineEntity = prefs.getString('salesLineEntity') ?? '';

    if (salesLineEntity == null || salesLineEntity!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Sales Line Entity not set. Check settings.'),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _createLine() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final lineData = {
      "dataAreaId": "usmf",
      "SalesOrderNumber": widget.salesOrderNumber,
      "ItemNumber": _itemIdController.text.trim(),
      "OrderedSalesQuantity":
          double.tryParse(_quantityController.text.trim()) ?? 1.0,
      "SalesPrice": double.tryParse(_priceController.text.trim()) ?? 0.0,
      "SalesPriceQuantity": 1.0,
      "LineDiscountAmount":
          double.tryParse(_discountController.text.trim()) ?? 0.0,
      "ShippingWarehouseId": _shippingWarehouseController.text.trim(),
      "ShippingSiteId": _siteController.text.trim(),
      "CurrencyCode": _currencyController.text.trim(),
    };

    final url = '${widget.resource}/data/$salesLineEntity';
    print('📦 API URL: $url');
    print('🟨 Sending line data: ${jsonEncode(lineData)}');

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

        Future.delayed(Duration(milliseconds: 500), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SalesOrderLinesScreen(
                orderNumber: widget.salesOrderNumber,
                accessToken: widget.accessToken,
                tenantId: widget.tenantId,
                clientId: widget.clientId,
                clientSecret: widget.clientSecret,
                resource: widget.resource,
                forceReload: true,
                orderFields: widget.orderFields,
              ),
            ),
          );
        });
      } else {
        print('❌ Error: ${response.statusCode} ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to create line. (${response.statusCode})'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('❗ Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Exception occurred.\n$e'),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
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
              _buildField(
                _itemIdController,
                'Item Number',
                isNumeric: false,
                required: true,
              ),
              _buildField(_quantityController, 'Quantity', isNumeric: true),
              _buildField(_priceController, 'Price', isNumeric: true),
              _buildField(_discountController, 'Discount', isNumeric: true),
              _buildField(
                _shippingWarehouseController,
                'Warehouse ID',
                required: true,
              ),
              _buildField(_siteController, 'Site ID', required: true),
              _buildField(_currencyController, 'Currency Code', required: true),
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

  Widget _buildField(
    TextEditingController controller,
    String label, {
    bool isNumeric = false,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        validator: (val) {
          if (required && (val == null || val.isEmpty)) return 'Required';
          return null;
        },
      ),
    );
  }
}
