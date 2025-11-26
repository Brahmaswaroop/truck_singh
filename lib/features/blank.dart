import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class BlankPage extends StatelessWidget {
  const BlankPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          tr('testPage'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: Center(
        child: Text(
          tr('blankTestPage'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}