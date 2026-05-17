import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.isAssistant,
    this.assistantColor = const Color(0xFF1A1F26),
    this.userColor = const Color(0xFF2E4A8B),
    this.textColor = Colors.white,
  });

  final String text;
  final bool isAssistant;
  final Color assistantColor;
  final Color userColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isAssistant ? assistantColor : userColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(text, style: TextStyle(color: textColor)),
      ),
    );
  }
}
