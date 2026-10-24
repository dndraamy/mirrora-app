import 'package:flutter/material.dart';
import 'mirrora_assistant_screen.dart';

/// Kompatibilitas mundur: Mengarahkan pemanggil lama `AiAssistantScreen`
/// ke layar asisten percakapan `MirroraAssistantScreen`.
class AiAssistantScreen extends StatelessWidget {
  const AiAssistantScreen({super.key, this.userName = 'Sarah'});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return MirroraAssistantScreen(userName: userName);
  }
}
