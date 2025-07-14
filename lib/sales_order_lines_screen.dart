import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'create_sales_line_screen.dart';
import 'd365_service.dart';

class SalesOrderLinesScreen extends StatefulWidget {
  final String orderNumber;
  final String accessToken;
  final String tenantId;
  final String clientId;
  final String clientSecret;
  final String resource;
  final Map<String, dynamic> orderFields;
  final bool forceReload;

  SalesOrderLinesScreen({
    required this.orderNumber,
    required this.accessToken,
    required this.tenantId,
    required this.clientId,
    required this.clientSecret,
    required this.resource,
    required this.orderFields,
    required this.forceReload,
  });

  @override
  _SalesOrderLinesScreenState createState() => _SalesOrderLinesScreenState();
}

class _SalesOrderLinesScreenState extends State<SalesOrderLinesScreen> {
  Map<String, String> filters = {};
  List<dynamic> lines = [];
  bool isLoading = true;

  bool get isInvoiced =>
      (widget.orderFields['SalesOrderStatus'] ?? '').toString().toLowerCase() ==
          'invoiced';

  @override
  void initState() {
    super.initState();
    _loadLines();
  }

  Future<void> _loadLines() async {
    final prefs = await SharedPreferences.getInstance();
    final service = D365Service(
      tenantId: widget.tenantId,
      clientId: widget.clientId,
      clientSecret: widget.clientSecret,
      resource: widget.resource,
    );
    final fetchedLines = await service.fetchSalesOrderLines(widget.orderNumber);
    setState(() {
      lines = fetchedLines;
      isLoading = false;
    });
  }

  List<dynamic> get filteredLines {
    return lines.where((line) {
      return filters.entries.every((filter) {
        final value = line[filter.key]?.toString() ?? '';
        return value.toLowerCase().contains(filter.value.toLowerCase());
      });
    }).toList();
  }

  Future<void> exportToCSV() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Storage permission denied')));
      return;
    }

    final headers = [
      'ItemNumber',
      'SalesProductCategoryName',
      'OrderedSalesQuantity',
      'SalesPrice',
      'LineAmount',
    ];
    final rows = filteredLines
        .map(
          (line) =>
      [
        line['ItemNumber']?.toString() ?? '',
        line['SalesProductCategoryName']?.toString() ?? '',
        line['OrderedSalesQuantity']?.toString() ?? '',
        line['SalesPrice']?.toString() ?? '',
        line['LineAmount']?.toString() ?? '',
      ],
    )
        .toList();

    final csvData = StringBuffer();
    csvData.writeln(headers.join(","));
    for (var row in rows) {
      csvData.writeln(row.join(","));
    }

    final directory =
        await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/sales_order_lines_${widget.orderNumber}.csv';
    final file = File(path);
    await file.writeAsString(csvData.toString());

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Exported to $path')));
  }

  void clearFilters() {
    setState(() {
      filters.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final columns = [
      {'key': 'ItemNumber', 'label': 'Item Number'},
      {'key': 'SalesProductCategoryName', 'label': 'Description'},
      {'key': 'OrderedSalesQuantity', 'label': 'Quantity'},
      {'key': 'SalesPrice', 'label': 'Unit Price'},
      {'key': 'LineAmount', 'label': 'Line Amount'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("Lines: ${widget.orderNumber}"),
        actions: [
          IconButton(
            icon: Icon(Icons.clear),
            tooltip: 'Clear Filters',
            onPressed: clearFilters,
          ),
          IconButton(
            icon: Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: exportToCSV,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : OrientationBuilder(
        builder: (context, orientation) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  if (lines.isNotEmpty)
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: columns.map((col) {
                                    return Container(
                                      width: 160,
                                      padding: EdgeInsets.all(8),
                                      child: TextField(
                                        decoration: InputDecoration(
                                          labelText: col['label'],
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            if (value.isEmpty) {
                                              filters.remove(col['key']);
                                            } else {
                                              filters[col['key']!] = value;
                                            }
                                          });
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                                DataTable(
                                  columns: columns
                                      .map((col) =>
                                      DataColumn(
                                          label: Text(col['label']!)))
                                      .toList(),
                                  rows: filteredLines.map((line) {
                                    return DataRow(cells: [
                                      DataCell(Text(
                                          line['ItemNumber']?.toString() ??
                                              '')),
                                      DataCell(Text(line[
                                      'SalesProductCategoryName']
                                          ?.toString() ??
                                          '')),
                                      DataCell(Text(line[
                                      'OrderedSalesQuantity']
                                          ?.toString() ??
                                          '')),
                                      DataCell(Text(
                                          line['SalesPrice']?.toString() ??
                                              '')),
                                      DataCell(Text(
                                          line['LineAmount']?.toString() ??
                                              '')),
                                    ]);
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Center(
                        child: Text("No lines found for this order."),
                      ),
                    ),
                  SizedBox(height: 16),
                  if (!isInvoiced)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CreateSalesLineScreen(
                                  salesOrderNumber: widget.orderNumber,
                                  accessToken: widget.accessToken,
                                  tenantId: widget.tenantId,
                                  clientId: widget.clientId,
                                  clientSecret: widget.clientSecret,
                                  resource: widget.resource,
                                  orderFields: widget.orderFields,
                                ),
                          ),
                        );
                      },
                      icon: Icon(Icons.add),
                      label: Text("Add New Line"),
                    ),
                  SizedBox(height: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
