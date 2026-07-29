import 'package:flutter/material.dart';

class SensorBox extends StatelessWidget {
  const SensorBox({
    super.key,
    required this.label,
    required this.value,
    required this.active,
  });

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(
            color: active ? Colors.indigo.shade50 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: active ? Colors.indigo : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
