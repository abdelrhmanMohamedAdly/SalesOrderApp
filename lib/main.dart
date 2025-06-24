import 'package:flutter/material.dart';
import 'package:sales_order_app/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SalesOrderApp());
}

class SalesOrderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sales Order App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: false),
      home: LoginScreen(),
    );
  }
}
