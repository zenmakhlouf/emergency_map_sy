import 'package:flutter/material.dart';

class LoadingUi extends StatelessWidget {
  const LoadingUi({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        strokeCap: StrokeCap.round,
      ),
    );
  }
}
