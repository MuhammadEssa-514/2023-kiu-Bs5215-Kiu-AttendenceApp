import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Schedule", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.blueGrey,iconTheme: const IconThemeData(color: Colors.white),),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "View Class Routine",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                const url =
                    'https://muhammadessa-514.github.io/My-Personal-Portfolio/';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                }
              },
              child: Text('Open Link'),
            ),
          ],
        ),
      ),
    );
  }
}
