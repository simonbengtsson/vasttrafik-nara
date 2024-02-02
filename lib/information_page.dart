import 'package:flutter/material.dart';
import 'package:vasttrafik_nara/common.dart';
import 'package:vasttrafik_nara/models.dart';

class InformationPage extends StatefulWidget {
  final Information information;

  const InformationPage({super.key, required this.information});

  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {
  @override
  void initState() {
    super.initState();
    trackEvent('Page Shown', {
      'Page Name': 'Information',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Information'),
        actions: [],
      ),
      body: Text('Information'),
    );
  }
}
