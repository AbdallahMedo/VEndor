import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';

class FirstTimeDialog extends StatelessWidget {
  final String firstName;
  final String lastName;
  final bool isAdmin;

  const FirstTimeDialog({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    String userType = isAdmin ? "Admin" : "User";
    String roleMessage = isAdmin
        ? "You have full permissions to manage vendors, categories, and items."
        : "You have limited permissions. Contact your admin for additional access.";

    String tips = """
- Use the + button to add items or categories.
- Tap on any category to view its contents.
- Export reports using the floating menu.
- Long press items for more actions.
""";

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      contentPadding: const EdgeInsets.all(24),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_people, size: 60, color: Colors.indigo),
            const SizedBox(height: 20),
            AnimatedTextKit(
              isRepeatingAnimation: false,
              animatedTexts: [
                TypewriterAnimatedText(
                  'Hi $firstName $lastName!',
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                  speed: const Duration(milliseconds: 80),
                ),
                TypewriterAnimatedText(
                  'Welcome to the Vendor System as $userType!',
                  textStyle: const TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                  speed: const Duration(milliseconds: 70),
                ),
                TypewriterAnimatedText(
                  roleMessage,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  speed: const Duration(milliseconds: 65),
                ),
                TypewriterAnimatedText(
                  tips,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                  speed: const Duration(milliseconds: 40),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: const Text("Got it!", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
