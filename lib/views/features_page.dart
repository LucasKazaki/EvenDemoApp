// ignore_for_file: library_private_types_in_public_api

import 'package:demo_ai_even/views/agent_studio_settings_page.dart';
import 'package:demo_ai_even/views/features/bmp_page.dart';
import 'package:demo_ai_even/views/features/notification/notification_page.dart';
import 'package:demo_ai_even/views/features/text_page.dart';
import 'package:flutter/material.dart';

class FeaturesPage extends StatefulWidget {
  const FeaturesPage({super.key});

  @override
  _FeaturesPageState createState() => _FeaturesPageState();
}

class _FeaturesPageState extends State<FeaturesPage> {
  Widget _featureTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(icon),
                const SizedBox(width: 16),
                Text(title, style: const TextStyle(fontSize: 16)),
                const Spacer(),
                const Icon(Icons.chevron_right),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Features'),
        ),
        body: ListView(
          padding:
              const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 44),
          children: [
            _featureTile(
              title: 'Agent Studio',
              icon: Icons.hub,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AgentStudioSettingsPage(),
                  ),
                );
              },
            ),
            _featureTile(
              title: 'BMP',
              icon: Icons.image_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BmpPage()),
                );
              },
            ),
            _featureTile(
              title: 'Notification',
              icon: Icons.notifications_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationPage(),
                  ),
                );
              },
            ),
            _featureTile(
              title: 'Text',
              icon: Icons.text_fields,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TextPage()),
                );
              },
            ),
          ],
        ),
      );
}
