import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'login_page/login_page.dart';
import 'profile_page/dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAb0TzjniE2iCEs-HFfpcxI5-3rRR2tkD0",
        authDomain: "studentattendanceapp-d5905.firebaseapp.com",
        projectId: "studentattendanceapp-d5905",
        storageBucket: "studentattendanceapp-d5905.firebasestorage.app",
        messagingSenderId: "569775601632",
        appId: "1:569775601632:web:0893152401b80d1970dd85",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KIU Smart Haziri - Muhammad Essa 5215',
      theme: ThemeData(primarySwatch: Colors.blueGrey, useMaterial3: true),
      home: const LoginPageWrapper(),
    );
  }
}

class LoginPageWrapper extends StatelessWidget {
  const LoginPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          User user = snapshot.data!;
          // Offline-Robust User Data Fetch
          return FutureBuilder<Map<String, String?>>(
            future: _fetchUserDataRobust(user),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final data = snap.data ?? {};
              String role = data['role'] ?? "student";
              String? rollno = data['rollno'];

              return DashboardPage(
                name: user.displayName ?? "User",
                email: user.email ?? "",
                role: role,
                rollno: rollno,
              );
            },
          );
        }
        return const LoginPage();
      },
    );
  }

  Future<Map<String, String?>> _fetchUserDataRobust(User user) async {
    try {
      // 1. Try Firestore
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        String role =
            data['role']?.toString().toLowerCase().trim() ?? 'student';
        String? roll = data['rollno']?.toString();

        // Cache locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_uid_${user.uid}_role', role);
        if (roll != null) {
          await prefs.setString('last_uid_${user.uid}_roll', roll);
        }

        return {'role': role, 'rollno': roll};
      }
    } catch (e) {
      print("Firestore user fetch failed (Offline?): $e");
    }

    // 2. Fallback to Local Cache
    try {
      final prefs = await SharedPreferences.getInstance();
      String role = prefs.getString('last_uid_${user.uid}_role') ?? 'student';
      String? roll = prefs.getString('last_uid_${user.uid}_roll');
      return {'role': role, 'rollno': roll};
    } catch (e) {
      return {'role': 'student', 'rollno': null};
    }
  }
}
