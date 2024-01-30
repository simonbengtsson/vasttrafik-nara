import 'package:vasttrafik_nara/common.dart';
import 'package:vasttrafik_nara/homePage.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initMixpanel();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Västtrafik Nära',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: Colors.white,
      ),
      home: MyHomePage(),
    );
  }
}
