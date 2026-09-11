import 'package:flutter/material.dart';

class SensorBox extends StatelessWidget {
  const SensorBox({
    super.key,
    required this.label,
    required this.value,
    required this.active,
    this.isWarning = false,
    this.warningMessage,
  });

  final String label;
  final String value;
  final bool active;
  final bool isWarning;
  final String? warningMessage;

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF008C83);

    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active 
                ? (isWarning ? Colors.amber.shade50 : brandColor.withValues(alpha: 0.1)) 
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active 
                  ? (isWarning ? Colors.amber : brandColor) 
                  : Colors.grey.shade300,
              width: isWarning ? 2.5 : 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: active 
                  ? (isWarning ? Colors.amber.shade900 : brandColor) 
                  : Colors.grey.shade600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (warningMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            warningMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.amber.shade900,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
