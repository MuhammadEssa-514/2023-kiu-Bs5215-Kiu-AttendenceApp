import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../login_page/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  final String name;
  final String email;
  final String password; // For demonstration purposes
  final String? roll; // To identify student in Firestore

  const ProfilePage({
    super.key,
    required this.name,
    required this.email,
    required this.password,
    this.roll,
    this.readOnly = false,
  });

  final bool readOnly;

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late String _name;
  late String _email;
  late String _password;
  File? _profileImage;
  static const String _profileImagePathKey = 'profile_image_path';

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _email = widget.email;
    _password = widget.password;
    _loadProfileImage();
  }

  // Load the profile image path from SharedPreferences
  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString(_profileImagePathKey);

    if (imagePath != null) {
      final file = File(imagePath);
      if (await file.exists()) {
        setState(() {
          _profileImage = file;
        });
      }
    }
  }

  // Save the profile image path to SharedPreferences
  Future<void> _saveProfileImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileImagePathKey, path);
  }

  Future<void> _updateFirestoreProfile(String newName) async {
    bool databaseUpdateSuccess = false;
    String? databaseError;

    try {
      final user = FirebaseAuth.instance.currentUser;

      // 1. ALWAYS Update Firebase Auth Profile (Login Display Name)
      // This usually works without special permissions
      if (user != null) {
        await user.updateDisplayName(newName);
      }

      // 2. ALWAYS Update Locally (Offline Fallback & Instant Feedback)
      if (widget.roll != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final cleanRoll = widget.roll!.trim();
          String key = 'student_$cleanRoll';

          // Helper to update json
          void updateJson(String k) {
            String? jsonStr = prefs.getString(k);
            if (jsonStr != null) {
              Map<String, dynamic> data = jsonDecode(jsonStr);
              data['name'] = newName;
              prefs.setString(k, jsonEncode(data));
            }
          }

          // Try specific key
          if (prefs.containsKey(key)) {
            updateJson(key);
          }
          // Try searching keys
          else {
            final allKeys = prefs.getKeys();
            for (String k in allKeys) {
              if (k.startsWith('student_')) {
                if (k.substring(8).trim().toLowerCase() ==
                    cleanRoll.toLowerCase()) {
                  updateJson(k);
                }
              }
            }
          }
        } catch (e) {
          print("Local update error: $e");
        }
      }

      // 3. TRY to Update Firestore (Might fail due to Permissions)
      try {
        // Update 'students' collection (Academic Record)
        if (widget.roll != null) {
          final rollParsed = int.tryParse(widget.roll!) ?? widget.roll;
          final q =
              await FirebaseFirestore.instance
                  .collection('students')
                  .where('roll', isEqualTo: rollParsed)
                  .get();
          if (q.docs.isNotEmpty) {
            await q.docs.first.reference.update({'name': newName});
            databaseUpdateSuccess = true;
          } else {
            final q2 =
                await FirebaseFirestore.instance
                    .collection('students')
                    .where('roll', isEqualTo: widget.roll)
                    .get();
            if (q2.docs.isNotEmpty) {
              await q2.docs.first.reference.update({'name': newName});
              databaseUpdateSuccess = true;
            }
          }
        }

        // Update 'users' collection (App Account)
        if (user != null) {
          final userDoc = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid);
          if ((await userDoc.get()).exists) {
            await userDoc.update({'name': newName});
          }
        }
      } catch (e) {
        print("Firestore permission error: $e");
        if (e.toString().contains("permission-denied")) {
          databaseError =
              "Name updated on Device (Server requires Admin approval)";
        } else {
          databaseError = "Name updated on Device (Server error: $e)";
        }
      }

      if (databaseUpdateSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Name updated successfully!")),
        );
      } else if (databaseError != null) {
        // Show success but with a warning (Orange)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(databaseError),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // Successful local update, simply no database match found
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Name updated locally!")));
      }
    } catch (e) {
      print("Critical error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _editProfile(BuildContext context) {
    TextEditingController nameController = TextEditingController(text: _name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Profile"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [_buildTextField("Full Name", nameController)],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _name = nameController.text;
                });
                await _updateFirestoreProfile(_name);
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    TextEditingController currentPwdController = TextEditingController();
    TextEditingController newPwdController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Change Password"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPwdController,
                    decoration: const InputDecoration(
                      labelText: "Current Password",
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPwdController,
                    decoration: const InputDecoration(
                      labelText: "New Password",
                    ),
                    obscureText: true,
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            setStateDialog(() => isLoading = true);
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null && user.email != null) {
                                final cred = EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: currentPwdController.text,
                                );
                                await user.reauthenticateWithCredential(cred);
                                await user.updatePassword(
                                  newPwdController.text,
                                );

                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Password Changed Successfully!",
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("No user logged in"),
                                  ),
                                );
                              }
                            } catch (e) {
                              String errorMessage = "An error occurred";
                              if (e.toString().contains("invalid-credential") ||
                                  e.toString().contains("wrong-password")) {
                                errorMessage =
                                    "Incorrect Current Password. Please try again.";
                              } else if (e.toString().contains(
                                "weak-password",
                              )) {
                                errorMessage = "New password is too weak.";
                              } else {
                                errorMessage = e.toString();
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    errorMessage,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setStateDialog(() => isLoading = false);
                              }
                            }
                          },
                  child: const Text("Update Password"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // Copy the image to app's documents directory to ensure persistence
      final String newPath = await _saveImageToAppDirectory(image.path);

      setState(() {
        _profileImage = File(newPath);
      });

      // Save the path for future app launches
      await _saveProfileImagePath(newPath);
    }
  }

  // Save image to application documents directory to ensure persistence
  Future<String> _saveImageToAppDirectory(String sourcePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final String fileName =
        'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String targetPath = '${directory.path}/$fileName';

    // Copy the image
    final File sourceFile = File(sourcePath);
    final File newImage = await sourceFile.copy(targetPath);

    return newImage.path;
  }

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final double avatarRadius = isSmallScreen ? 60 : 50;
    final double nameFontSize = isSmallScreen ? 26 : 22;
    final double emailFontSize = isSmallScreen ? 18 : 15;
    final double fieldFontSize = isSmallScreen ? 17 : 14;
    final double buttonFontSize = isSmallScreen ? 18 : 15;
    final double buttonWidth = isSmallScreen ? 220 : 180;
    final double buttonHeight = isSmallScreen ? 50 : 44;
    final double cardPadding = isSmallScreen ? 20 : 16;

    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: "Logout",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(cardPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                GestureDetector(
                  onTap: widget.readOnly ? null : _pickImage,
                  child: CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: Colors.blueGrey,
                    backgroundImage:
                        _profileImage != null
                            ? FileImage(_profileImage!)
                            : null,
                    child:
                        _profileImage == null
                            ? Text(
                              _name.isNotEmpty ? _name[0].toUpperCase() : "U",
                              style: TextStyle(
                                fontSize: avatarRadius * 0.9,
                                color: Colors.white,
                              ),
                            )
                            : null,
                  ),
                ),
                SizedBox(height: 10),
                if (!widget.readOnly)
                  TextButton(
                    onPressed: _pickImage,
                    child: Text(
                      "Change Profile Picture",
                      style: TextStyle(fontSize: fieldFontSize),
                    ),
                  ),
                if (widget.readOnly) SizedBox(height: 10),
                SizedBox(height: 20),
                Text(
                  _name,
                  style: TextStyle(
                    fontSize: nameFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  _email,
                  style: TextStyle(fontSize: emailFontSize, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 30),
                Divider(),
                SizedBox(height: 20),
                _buildProfileField("Full Name", _name, fieldFontSize),
                _buildProfileField("Email", _email, fieldFontSize),
                _buildProfileField(
                  "Password",
                  _password.replaceAll(RegExp(r"."), "*"),
                  fieldFontSize,
                ),
                SizedBox(height: 40),
                if (!widget.readOnly) ...[
                  ElevatedButton.icon(
                    onPressed: () => _editProfile(context),
                    icon: Icon(Icons.edit),
                    label: Text(
                      "Edit Name",
                      style: TextStyle(fontSize: buttonFontSize),
                    ),
                    style: ElevatedButton.styleFrom(
                      elevation: 2.0,
                      fixedSize: Size(buttonWidth, buttonHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showChangePasswordDialog(context),
                    icon: Icon(Icons.lock_reset),
                    label: Text(
                      "Change Password",
                      style: TextStyle(fontSize: buttonFontSize),
                    ),
                    style: ElevatedButton.styleFrom(
                      elevation: 2.0,
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      fixedSize: Size(buttonWidth, buttonHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
                SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    _logout(context);
                  },
                  icon: Icon(Icons.logout),
                  label: Text(
                    "Logout",
                    style: TextStyle(fontSize: buttonFontSize),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 2.0,
                    fixedSize: Size(buttonWidth, buttonHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileField(String title, String value, double fontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$title:",
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: fontSize, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
    );
  }
}
