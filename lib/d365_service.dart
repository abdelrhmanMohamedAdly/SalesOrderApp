import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class D365Service {
  final String tenantId;
  final String clientId;
  final String clientSecret;
  final String resource;

  D365Service({
    required this.tenantId,
    required this.clientId,
    required this.clientSecret,
    required this.resource,
  });

  Future<String?> getAccessToken() async {
    final url = Uri.parse(
      'https://login.microsoftonline.com/$tenantId/oauth2/token',
    );

    final response = await http.post(
      url,
      body: {
        'grant_type': 'client_credentials',
        'client_id': clientId,
        'client_secret': clientSecret,
        'resource': resource,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['access_token'];
    } else {
      print("❌ Failed to get token");
      print("Status: ${response.statusCode}");
      print("Body: ${response.body}");
      return null;
    }
  }

  Future<List<dynamic>> fetchSalesOrders() async {
    final token = await getAccessToken();
    if (token == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final entity = prefs.getString('salesOrderEntity') ?? '';
    final url = Uri.parse('$resource/data/$entity');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['value'] ?? [];
    } else {
      print("❌ API Call Failed (Orders)");
      print("Status: ${response.statusCode}");
      return [];
    }
  }

  Future<List<dynamic>> fetchSalesOrderLines(String salesOrderNumber) async {
    final token = await getAccessToken();
    if (token == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final entity = prefs.getString('salesLineEntity') ?? '';
    final url = Uri.parse(
      "$resource/data/$entity?\$filter=SalesOrderNumber eq '$salesOrderNumber'",
    );

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['value'] ?? [];
    } else {
      print("❌ Failed to fetch order lines");
      print("Status: ${response.statusCode}");
      return [];
    }
  }

  Future<String?> createSalesOrder(
    String accessToken,
    Map<String, dynamic> orderData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final entity = prefs.getString('salesOrderEntity') ?? '';
    final url = Uri.parse('$resource/data/$entity');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(orderData),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['SalesOrderNumber'];
    } else {
      print('❌ Failed to create sales order: ${response.body}');
      return null;
    }
  }

  Future<bool> createSalesOrderLine(
    String accessToken,
    String salesOrderNumber,
    Map<String, dynamic> lineData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final entity = prefs.getString('salesLineEntity') ?? '';
    final url = Uri.parse("$resource/data/$entity");

    final payload = {
      "dataAreaId": "usmf",
      "SalesOrderNumber": salesOrderNumber,
      "ItemNumber": lineData["ItemNumber"],
      "OrderedSalesQuantity": lineData["OrderedSalesQuantity"],
      "SalesPrice": lineData["SalesPrice"],
      "SalesPriceQuantity": lineData["SalesPriceQuantity"],
      "LineDiscountAmount": lineData["LineDiscountAmount"],
      "ShippingWarehouseId": lineData["ShippingWarehouseId"],
      "CurrencyCode": lineData["CurrencyCode"],
      "ShippingSiteId": lineData["ShippingSiteId"],
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        print("❌ API Error ${response.statusCode}");
        print("Body: ${response.body}");
        return false;
      }
    } catch (e) {
      print('❌ Exception during createSalesOrderLine: $e');
      return false;
    }
  }

  Future<List<String>> getCustomers(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final entity = prefs.getString('salesOrderEntity') ?? '';
    final uri = Uri.parse("$resource/data/$entity");

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final orders = data['value'] as List;
        return orders
            .map<String>(
              (order) => order['InvoiceCustomerAccountNumber'] ?? 'Unknown',
            )
            .toSet()
            .toList();
      } else {
        throw Exception(
          '❌ Failed to fetch sales order customers: ${response.statusCode}\n${response.body}',
        );
      }
    } catch (e) {
      print('❗ Exception during getCustomers: $e');
      rethrow;
    }
  }
}
