import 'package:flutter/material.dart';

class CustomLetterIcon extends StatelessWidget {
  final String letter;

  const CustomLetterIcon({Key? key, required this.letter}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        color: Colors.blue, // الدائرة الزرقاء التي طلبتها
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.red, // الحرف الأحمر الذي طلبته
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}