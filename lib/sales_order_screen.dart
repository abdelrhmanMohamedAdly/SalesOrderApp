import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Sales_Entities_Screen.dart';
import 'new_sales_order_Screen.dart';
import 'd365_service.dart';
import 'sales_order_lines_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class SalesOrderScreen extends StatefulWidget {
  final String tenantId;
  final String clientId;
  final String clientSecret;
  final String resource;
  final String salesOrderEntity;
  final String salesLineEntity;

  SalesOrderScreen({
    required this.tenantId,
    required this.clientId,
    required this.clientSecret,
    required this.resource,
    required this.salesOrderEntity,
    required this.salesLineEntity,
  });

  @override
  _SalesOrderScreenState createState() => _SalesOrderScreenState();
}

class _SalesOrderScreenState extends State<SalesOrderScreen> {
  List<dynamic> orders = [];
  List<dynamic> filteredOrdersList = [];
  bool isLoading = false;
  String? errorMessage;

  Map<String, Map<String, dynamic>> columnFilters = {};

  @override
  void initState() {
    super.initState();
    _loadSavedOrders();
  }

  Future<void> _loadSavedOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('salesOrders');
    if (savedData != null) {
      final List<dynamic> savedOrders = json.decode(savedData);
      setState(() {
        orders = savedOrders;
        filteredOrdersList = List.from(orders);
        errorMessage = null;
      });
    } else {
      setState(() {
        errorMessage = "No saved sales orders found. Please refresh.";
      });
    }
  }

  Future<void> _refreshOrders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final salesOrderEntity = prefs.getString('salesOrderEntity') ?? '';

    final service = D365Service(
      tenantId: widget.tenantId,
      clientId: widget.clientId,
      clientSecret: widget.clientSecret,
      resource: widget.resource,
    );

    try {
      final newOrders = await service.fetchSalesOrders() ?? [];

      if (newOrders.isEmpty) {
        setState(() {
          errorMessage = "No sales orders found from API.";
          isLoading = false;
        });
        return;
      }

      final existingOrderNumbers =
      orders.map((e) => e['SalesOrderNumber']).toSet();
      final filteredNewOrders = newOrders
          .where(
            (order) =>
            !existingOrderNumbers.contains(order['SalesOrderNumber']),
      )
          .toList();

      if (filteredNewOrders.isNotEmpty) {
        orders.addAll(filteredNewOrders);
        await prefs.setString('salesOrders', json.encode(orders));
      }

      setState(() {
        filteredOrdersList = List.from(orders);
        isLoading = false;
        errorMessage = filteredNewOrders.isEmpty
            ? "No new sales orders to add."
            : null;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Error loading sales orders: $e";
        isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('salesOrders');
    setState(() {
      orders.clear();
      filteredOrdersList.clear();
      errorMessage = "Cache cleared. Please refresh.";
    });
  }

  Future<void> _createNewOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final salesOrderEntity = prefs.getString('salesOrderEntity') ?? '';

    final service = D365Service(
      tenantId: widget.tenantId,
      clientId: widget.clientId,
      clientSecret: widget.clientSecret,
      resource: widget.resource,
    );

    final accessToken = await service.getAccessToken() ?? '';

    final createdOrderNumber = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewSalesOrderScreen(
          accessToken: accessToken,
          tenantId: widget.tenantId,
          clientId: widget.clientId,
          clientSecret: widget.clientSecret,
          resource: widget.resource,
        ),
      ),
    );

    if (createdOrderNumber != null) {
      await _refreshOrders();
      final salesLineEntity = prefs.getString('salesLineEntity') ?? '';

      final lineService = D365Service(
        tenantId: widget.tenantId,
        clientId: widget.clientId,
        clientSecret: widget.clientSecret,
        resource: widget.resource,
      );

      final lines = await lineService.fetchSalesOrderLines(createdOrderNumber);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SalesOrderLinesScreen(
            orderNumber: createdOrderNumber,
            accessToken: accessToken,
            tenantId: widget.tenantId,
            clientId: widget.clientId,
            clientSecret: widget.clientSecret,
            resource: widget.resource,
            orderFields: {},
            forceReload: true,
          ),
        ),
      );
    }
  }

  void _applyFilters() {
    setState(() {
      filteredOrdersList = orders.where((order) {
        for (var col in columnFilters.keys) {
          var filterType = columnFilters[col]!['type'];
          var filterValue = columnFilters[col]!['value']
              .toString()
              .toLowerCase();
          var fieldValue = order[col]?.toString().toLowerCase() ?? '';

          if (filterValue.isEmpty) continue;

          switch (filterType) {
            case 'Contains':
              if (!fieldValue.contains(filterValue)) return false;
              break;
            case 'Equals':
              if (fieldValue != filterValue) return false;
              break;
            case 'Begins With':
              if (!fieldValue.startsWith(filterValue)) return false;
              break;
            case 'Ends With':
              if (!fieldValue.endsWith(filterValue)) return false;
              break;
            case 'Is One Of':
              var values = filterValue.split(',').map((e) => e.trim()).toList();
              if (!values.contains(fieldValue)) return false;
              break;
          }
        }
        return true;
      }).toList();
    });
  }

  void _showFilterDialog(String columnName) {
    String selectedFilter = 'Contains';
    TextEditingController valueController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text('Filter: $columnName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: selectedFilter,
                  items: [
                    'Contains',
                    'Equals',
                    'Begins With',
                    'Ends With',
                    'Is One Of'
                  ]
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => selectedFilter = v!);
                  },
                ),
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(hintText: 'Enter value'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    columnFilters[columnName] = {
                      'type': selectedFilter,
                      'value': valueController.text
                    };
                  });
                  _applyFilters();
                  Navigator.pop(context);
                },
                child: Text('Apply'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    columnFilters.remove(columnName);
                  });
                  _applyFilters();
                  Navigator.pop(context);
                },
                child: Text('Clear'),
              ),
            ],
          ),
    );
  }

  void _openMenuOption(String value) {
    if (value == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SettingsScreen()),
      );
    } else if (value == 'logout') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
            (_) => false,
      );
    } else if (value == 'entities') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SalesEntitiesScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sales Orders'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: isLoading ? null : _refreshOrders,
          ),
          IconButton(icon: Icon(Icons.delete), onPressed: _clearCache),
          IconButton(icon: Icon(Icons.add), onPressed: _createNewOrder),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: _openMenuOption,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'entities', child: Text('Entities')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: PaginatedDataTable(
          header: Text('Sales Orders'),
          rowsPerPage: 10,
          columns: [
            DataColumn(
              label: Row(
                children: [
                  Text('SalesOrderNumber'),
                  IconButton(
                    icon: Icon(Icons.filter_list, size: 18),
                    onPressed: () => _showFilterDialog('SalesOrderNumber'),
                  ),
                ],
              ),
            ),
            DataColumn(
              label: Row(
                children: [
                  Text('SalesOrderName'),
                  IconButton(
                    icon: Icon(Icons.filter_list, size: 18),
                    onPressed: () => _showFilterDialog('SalesOrderName'),
                  ),
                ],
              ),
            ),
            DataColumn(
              label: Row(
                children: [
                  Text('SalesOrderStatus'),
                  IconButton(
                    icon: Icon(Icons.filter_list, size: 18),
                    onPressed: () => _showFilterDialog('SalesOrderStatus'),
                  ),
                ],
              ),
            ),
            DataColumn(
              label: Row(
                children: [
                  Text('OrderTotalChargesAmount'),
                  IconButton(
                    icon: Icon(Icons.filter_list, size: 18),
                    onPressed: () =>
                        _showFilterDialog('OrderTotalChargesAmount'),
                  ),
                ],
              ),
            ),
          ],
          source: _SalesOrderDataSource(
            filteredOrdersList,
            context,
            widget.tenantId,
            widget.clientId,
            widget.clientSecret,
            widget.resource,
          ),
        ),
      ),
    );
  }
}

class _SalesOrderDataSource extends DataTableSource {
  final List<dynamic> data;
  final BuildContext context;
  final String tenantId;
  final String clientId;
  final String clientSecret;
  final String resource;

  _SalesOrderDataSource(this.data,
      this.context,
      this.tenantId,
      this.clientId,
      this.clientSecret,
      this.resource,);

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final order = data[index];
    return DataRow(
      cells: [
        DataCell(Text(order['SalesOrderNumber'] ?? '')),
        DataCell(Text(order['SalesOrderName'] ?? '')),
        DataCell(Text(order['SalesOrderStatus'] ?? '')),
        DataCell(Text(order['OrderTotalChargesAmount']?.toString() ?? '0')),
      ],
      onSelectChanged: (selected) async {
        if (selected == true) {
          final service = D365Service(
            tenantId: tenantId,
            clientId: clientId,
            clientSecret: clientSecret,
            resource: resource,
          );
          final accessToken = await service.getAccessToken() ?? '';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SalesOrderLinesScreen(
                    orderNumber: order['SalesOrderNumber'],
                    accessToken: accessToken,
                    tenantId: tenantId,
                    clientId: clientId,
                    clientSecret: clientSecret,
                    resource: resource,
                    orderFields: order,
                    forceReload: true,
                  ),
            ),
          );
        }
      },
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => data.length;

  @override
  int get selectedRowCount => 0;
}

