import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../profile_page/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;

  Future<void> _login() async {
    setState(() => loading = true);
    try {
      UserCredential uc = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: emailCtrl.text.trim(),
            password: passCtrl.text.trim(),
          );

      DocumentSnapshot doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uc.user!.uid)
              .get();

      String userRole = "student"; // default fallback
      String? rollno;
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        String? firebaseRole = data['role'] as String?;
        rollno = data['rollno']?.toString();
        if (firebaseRole != null) {
          String cleaned = firebaseRole.toLowerCase().trim();
          if (cleaned == "teacher" || cleaned == "admin") {
            userRole = "teacher";
          } else {
            userRole = "student";
          }
        }
      }
      print("USER ROLE FROM FIRESTORE: $userRole");

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => DashboardPage(
                  name: uc.user!.displayName ?? "User",
                  email: uc.user!.email!,
                  role: userRole,
                  rollno: rollno,
                ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login Failed: $e")));
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A1D56), Color(0xFF1E40AF)],
          ),
        ),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(20),
            elevation: 20,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 7,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        "assets/images/kiulogo.png",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "KIU Smart Haziri",
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A1D56),
                    ),
                  ),
                  const Text(
                    "Karakoram International University",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                      ),
                      onPressed: loading ? null : _login,
                      child:
                          loading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Text(
                                "LOGIN",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
