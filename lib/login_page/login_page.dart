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

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uc.user!.uid)
          .get();

      String userRole = "student";
      String? rollno;

      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        String? firebaseRole = data['role'];
        rollno = data['rollno']?.toString();

        if (firebaseRole != null &&
            (firebaseRole.toLowerCase() == "teacher" ||
                firebaseRole.toLowerCase() == "admin")) {
          userRole = "teacher";
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardPage(
              name: uc.user!.displayName ?? "User",
              email: uc.user!.email!,
              role: userRole,
              rollno: rollno,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Login Failed: $e")));
    }
    setState(() => loading = false);
  }

  Future<void> _forgotPassword() async {
    if (emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter your email first")),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailCtrl.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔥 Background image blur effect
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/bglogin.jpeg"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Semi-transparent overlay
          Container(
            color: Colors.black.withOpacity(0.45),
          ),

          // Login Card
          Center(
            child: Container(
              padding: const EdgeInsets.all(35),
              width: 420,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white.withOpacity(0.6),
                    backgroundImage:
                        const AssetImage("assets/images/kiulogo.png"),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "KIU Smart Haziri",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "Karakoram International University",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 35),

                  // Email Input
                  TextField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      labelText: "Email Address",
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.email, color: Colors.white),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Password Input
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      labelText: "Password",
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.5)),
                      ),
                    ),
                  ),

                  // Forgot Password
                  // Align(
                  //   alignment: Alignment.centerRight,
                  //   child: TextButton(
                  //     onPressed: _forgotPassword,
                  //     child: const Text(
                  //       "Forgot Password?",
                  //       style: TextStyle(color: Colors.white),
                  //     ),
                  //   ),
                  // ),

                  const SizedBox(height: 10),

                 // Login Button
SizedBox(
  width: double.infinity,
  height: 55,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      backgroundColor: Colors.blueAccent,
    ),
    onPressed: loading ? null : _login,
    child: loading
        ? const CircularProgressIndicator(
            color: Colors.white,
          )
        : const Text(
            "LOGIN",
            style: TextStyle(
              fontSize: 18,
       
              color: Colors.white, // <- MAKE TEXT WHITE
            ),
          ),
  ),
),
SizedBox(height: 10),

Text(
  "Muhammad Essa 2023-kiu-bs5215 \n BSCS Section A Group 7",
  textAlign: TextAlign.center,
  style: TextStyle(
    fontSize: 14,
    color: Colors.white70,
  ),
),



                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
