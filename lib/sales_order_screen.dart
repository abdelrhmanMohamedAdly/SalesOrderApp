import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool isLoading = false;
  String? errorMessage;
  String searchQuery = '';

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

      final existingOrderNumbers = orders
          .map((e) => e['SalesOrderNumber'])
          .toSet();
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

  List<dynamic> get filteredOrders {
    if (searchQuery.isEmpty) return orders;
    return orders
        .where(
          (order) =>
              (order['SalesOrderNumber'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()) ||
              (order['SalesOrderName'] ?? '').toString().toLowerCase().contains(
                searchQuery.toLowerCase(),
              ),
        )
        .toList();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: InputDecoration(
            hintText: 'Search Orders...',
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => searchQuery = value),
        ),
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
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: filteredOrders.length,
              itemBuilder: (context, index) {
                final order = filteredOrders[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.shopping_cart, color: Colors.blue),
                    title: Text(
                      "Order: ${order['SalesOrderNumber'] ?? 'N/A'}",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Customer: ${order['SalesOrderName'] ?? 'N/A'}"),
                        Text("Status: ${order['SalesOrderStatus'] ?? 'N/A'}"),
                        Text(
                          "Total: ${order['OrderTotalChargesAmount'] ?? '0'}",
                        ),
                      ],
                    ),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final salesLineEntity =
                          prefs.getString('salesLineEntity') ?? '';

                      final service = D365Service(
                        tenantId: widget.tenantId,
                        clientId: widget.clientId,
                        clientSecret: widget.clientSecret,
                        resource: widget.resource,
                      );
                      final accessToken = await service.getAccessToken() ?? '';
                      final orderNumber = order['SalesOrderNumber'];
                      final lines = await service.fetchSalesOrderLines(
                        orderNumber,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SalesOrderLinesScreen(
                            orderNumber: orderNumber,
                            accessToken: accessToken,
                            tenantId: widget.tenantId,
                            clientId: widget.clientId,
                            clientSecret: widget.clientSecret,
                            resource: widget.resource,
                            orderFields: order,
                            forceReload: true,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
