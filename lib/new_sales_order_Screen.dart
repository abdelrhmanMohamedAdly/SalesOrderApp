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
  bool _isSubmitting = false;

  List<String> _customers = [];
  List<Map<String, String>> _warehouses = [];
  List<String> _sites = [];
  List<String> _currencies = [];

  String? _selectedCustomer;
  String? _selectedWarehouse;
  String? _selectedSite;
  String? _selectedCurrency;

  String? tenantId, clientId, clientSecret, resource;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndData();
  }

  Future<void> _loadSettingsAndData() async {
    final prefs = await SharedPreferences.getInstance();
    tenantId = prefs.getString('tenantId');
    clientId = prefs.getString('clientId');
    clientSecret = prefs.getString('clientSecret');
    resource = prefs.getString('resource');

    if ([tenantId, clientId, clientSecret, resource].contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('⚠️ Missing settings. Please check app settings.')),
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
      final warehouses = await service.getWarehouses(widget.accessToken);

      setState(() {
        _customers = customers;
        _warehouses = warehouses;
        _currencies = ['USD', 'EUR', 'GBP', 'EGP', 'SAR', 'AED'];

        if (_customers.isNotEmpty) {
          _selectedCustomer = customers.first
              .split(' - ')
              .first;
        }
        if (_warehouses.isNotEmpty) {
          _selectedWarehouse = _warehouses.first['InventLocationId'];
          final siteId = _warehouses.first['InventSiteId'];
          if (siteId != null && siteId.isNotEmpty) {
            _loadSites(siteId);
          }
        }
        if (_currencies.isNotEmpty) _selectedCurrency = _currencies.first;
      });
    } catch (e) {
      print('❌ Error during loading: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  Future<void> _loadSites(String siteId) async {
    final service = D365Service(
      tenantId: tenantId!,
      clientId: clientId!,
      clientSecret: clientSecret!,
      resource: resource!,
    );

    try {
      final sites = await service.getSites(widget.accessToken, siteId);
      setState(() {
        _sites = sites;
        if (_sites.isNotEmpty) _selectedSite = sites.first
            .split(' - ')
            .first;
      });
    } catch (e) {
      print('❌ Failed to load sites: $e');
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final orderData = {
      "dataAreaId": "usmf",
      "SalesOrderName": "Contoso Europe",
      "CurrencyCode": _selectedCurrency,
      "InvoiceCustomerAccountNumber": _selectedCustomer,
      "OrderingCustomerAccountNumber": _selectedCustomer,
      "LanguageId": "en-us",
      "DefaultShippingWarehouseId": _selectedWarehouse,
      "DefaultShippingSiteId": _selectedSite,
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
                isExpanded: true,
                value: _customers.firstWhere(
                      (c) => c.startsWith(_selectedCustomer ?? ''),
                  orElse: () => '',
                ),
                decoration: InputDecoration(labelText: 'Select Customer'),
                items: _customers
                    .map((c) =>
                    DropdownMenuItem(
                      value: c,
                      child: Text(
                          c, overflow: TextOverflow.ellipsis, maxLines: 1),
                    ))
                    .toList(),
                onChanged: (val) =>
                    setState(() =>
                    _selectedCustomer = val
                        ?.split(' - ')
                        .first),
                validator: (val) =>
                val == null || val.isEmpty
                    ? 'Required'
                    : null,
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedWarehouse,
                decoration: InputDecoration(labelText: 'Warehouse'),
                items: _warehouses
                    .map((w) =>
                    DropdownMenuItem(
                      value: w['InventLocationId'],
                      child: Text(
                        "${w['InventLocationId']} - ${w['Name']}",
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ))
                    .toList(),
                onChanged: (val) {
                  final selected = _warehouses.firstWhere((
                      w) => w['InventLocationId'] == val);
                  setState(() {
                    _selectedWarehouse = val;
                    _selectedSite = null;
                  });
                  if (selected['InventSiteId'] != null) {
                    _loadSites(selected['InventSiteId']!);
                  }
                },
                validator: (val) => val == null ? 'Required' : null,
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _sites.firstWhere(
                      (s) => s.startsWith(_selectedSite ?? ''),
                  orElse: () => '',
                ),
                decoration: InputDecoration(labelText: 'Site'),
                items: _sites
                    .map((s) =>
                    DropdownMenuItem(
                      value: s,
                      child: Text(
                          s, overflow: TextOverflow.ellipsis, maxLines: 1),
                    ))
                    .toList(),
                onChanged: (val) =>
                    setState(() =>
                    _selectedSite = val
                        ?.split(' - ')
                        .first),
                validator: (val) => val == null ? 'Required' : null,
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedCurrency,
                decoration: InputDecoration(labelText: 'Currency'),
                items: _currencies
                    .map((c) =>
                    DropdownMenuItem(
                      value: c,
                      child: Text(
                          c, overflow: TextOverflow.ellipsis, maxLines: 1),
                    ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCurrency = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
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
}
