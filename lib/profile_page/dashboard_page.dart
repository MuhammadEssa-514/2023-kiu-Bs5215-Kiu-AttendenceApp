import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb

// Pages
import 'attendance_page.dart';
import 'reports_page.dart';
import 'schedule_page.dart';
import '../login_page/login_page.dart';
import 'manage_students_page.dart';

class DashboardPage extends StatefulWidget {
  final String name;
  final String email;
  final String role;
  final String? rollno;

  const DashboardPage({
    super.key,
    required this.name,
    required this.email,
    required this.role,
    this.rollno,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const List<String> courses = [
    "Mobile App",
    "Web Technologies",
    "Computer Architecture",
    "HCI and Graphics",
    "Introduction to Management",
  ];

  File? _profileImage;
  String? _profileImageUrl; // Web URL
  String _currentName = "";
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _currentName = widget.name;
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = FirebaseAuth.instance.currentUser;

    // 1. Try Auth Cache
    if (user?.photoURL != null) {
      if (mounted) setState(() => _profileImageUrl = user!.photoURL);
    }

    // 2. Fetch from Firestore (Source of Truth for Image AND Name)
    if (user != null) {
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;

          // Update Image
          if (data.containsKey('photoUrl')) {
            if (mounted) setState(() => _profileImageUrl = data['photoUrl']);
          }

          // Update Name (Fix for Teacher Name not showing)
          if (data.containsKey('name')) {
            if (mounted) setState(() => _currentName = data['name']);
          }
        }
      } catch (e) {
        print("Error loading profile data from DB: $e");
      }
    }

    // 3. Also check local cache (Mobile Only)
    if (!kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final localPath = prefs.getString('profile_image_path');
      if (localPath != null && File(localPath).existsSync()) {
        if (mounted) setState(() => _profileImage = File(localPath));
      }
    }
  }

  Widget _buildTeacherDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 15),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 2; // Mobile default
            double ratio = 1.3;

            if (constraints.maxWidth > 900) {
              crossAxisCount = 4; // Web/Desktop: 4 columns (Small cards)
              ratio = 1.3;
            } else if (constraints.maxWidth > 600) {
              crossAxisCount = 3; // Tablet: 3 columns
            }

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: ratio,
              children: [
                HoverCard(
                  icon: Icons.check_circle,
                  title: "Take Attendance",
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AttendancePage(),
                        ),
                      ),
                ),
                HoverCard(
                  icon: Icons.people,
                  title: "Manage Students",
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageStudentsPage(),
                        ),
                      ),
                ),
                HoverCard(
                  icon: Icons.analytics,
                  title: "View Reports",
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => AttendanceReportPage(role: widget.role),
                        ),
                      ),
                ),
                HoverCard(
                  icon: Icons.calendar_month,
                  title: "Schedule",
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SchedulePage()),
                      ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ==========================================
  //  IMAGE LOGIC (REAL FIREBASE UPLOAD - WEB & MOBILE)
  // ==========================================
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // 1. Show Uploading Indicator
      setState(() => _isUploading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception("User not logged in");

        String? uploadedUrl;

        if (kIsWeb) {
          // ----------------- WEB LOGIC -----------------
          // Instant Preview (Blob URL)
          setState(
            () => _profileImageUrl = image.path,
          ); // Temporarily show local blob

          final bytes = await image.readAsBytes();
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child('${user.uid}.jpg');

          // Upload Bytes
          await storageRef.putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          uploadedUrl = await storageRef.getDownloadURL();
        } else {
          // ----------------- MOBILE LOGIC -----------------
          // Local Save (Persistence)
          final directory = await getApplicationDocumentsDirectory();
          final String fileName =
              'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final String targetPath = '${directory.path}/$fileName';
          final File sourceFile = File(image.path);
          final File newImage = await sourceFile.copy(targetPath);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('profile_image_path', newImage.path);

          setState(() => _profileImage = newImage);

          // Upload File
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child('${user.uid}.jpg');
          await storageRef.putFile(newImage);
          uploadedUrl = await storageRef.getDownloadURL();
        }

        // 4. Update Auth & Firestore (Users + Students)
        // A. Update Auth
        await user.updatePhotoURL(uploadedUrl);

        // B. Update 'users' collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'photoUrl': uploadedUrl});

        // C. Update 'students' collection
        if (widget.rollno != null) {
          try {
            final rollParsed = int.tryParse(widget.rollno!) ?? widget.rollno;
            // Try finding by Int Roll
            final q =
                await FirebaseFirestore.instance
                    .collection('students')
                    .where('roll', isEqualTo: rollParsed)
                    .get();
            if (q.docs.isNotEmpty) {
              await q.docs.first.reference.update({'photoUrl': uploadedUrl});
            } else {
              // Try finding by String Roll
              final q2 =
                  await FirebaseFirestore.instance
                      .collection('students')
                      .where('roll', isEqualTo: widget.rollno)
                      .get();
              if (q2.docs.isNotEmpty) {
                await q2.docs.first.reference.update({'photoUrl': uploadedUrl});
              }
            }
          } catch (e) {
            print("Error syncing image to students collection: $e");
          }
        }

        setState(() {
          _profileImageUrl = uploadedUrl;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Profile Picture Updated Everywhere!"),
            ),
          );
        }
      } catch (e) {
        print("Upload Error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Upload Error: $e"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  ImageProvider? _getAvatarImage() {
    // Priority: 1. URL (Web/Network), 2. File (Mobile Local)
    if (_profileImageUrl != null) return NetworkImage(_profileImageUrl!);
    if (!kIsWeb && _profileImage != null) return FileImage(_profileImage!);
    return null;
  }

  // ==========================================
  //  AUTH LOGIC
  // ==========================================
  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  // ==========================================
  //  UI BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final bool isTeacher = widget.role.toLowerCase() == "teacher";

    // Header Avatar Widget
    final avatarWidget = CircleAvatar(
      radius: 20,
      backgroundColor: Colors.white,
      backgroundImage: _getAvatarImage(),
      child:
          _getAvatarImage() == null
              ? Text(
                _currentName.isNotEmpty ? _currentName[0].toUpperCase() : "U",
                style: TextStyle(
                  color: Colors.blueGrey[600],
                  fontWeight: FontWeight.bold,
                ),
              )
              : null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isTeacher ? "Teacher Dashboard" : "Student Dashboard",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold, // optional
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: Colors.blueGrey[600],
        elevation: 0,
        actions: [
          GestureDetector(
            onTap: () => _showProfileDialog(context),
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: avatarWidget,
            ),
          ),
        ],
      ),

      // PROFESSIONAL DRAWER
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.blueGrey[600]),
              accountName: Text(
                _currentName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              accountEmail: Text(widget.email),
              currentAccountPicture: GestureDetector(
                onTap: _pickImage, // Allow changing image from drawer too
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: _getAvatarImage(),
                  child:
                      _isUploading
                          ? const CircularProgressIndicator()
                          : (_getAvatarImage() == null
                              ? Text(
                                _currentName.isNotEmpty
                                    ? _currentName[0].toUpperCase()
                                    : "U",
                                style: TextStyle(
                                  fontSize: 30,
                                  color: Colors.blueGrey[900],
                                ),
                              )
                              : null),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            if (!isTeacher) ...[
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Class Schedule'),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SchedulePage()),
                    ),
              ),
            ],
            if (isTeacher) ...[
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Manage Students'),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageStudentsPage(),
                      ),
                    ),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('Take Attendance'),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AttendancePage()),
                    ),
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Profile Settings'),
              onTap: () {
                Navigator.pop(context);
                _showProfileDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.grey[100], // Light background for contrast
        height: double.infinity,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Welcome Banner
              _buildWelcomeCard(isTeacher),
              const SizedBox(height: 20),

              // Student View
              if (widget.rollno != null && !isTeacher) _buildStudentDashboard(),

              // Teacher View
              if (isTeacher) _buildTeacherDashboard(context),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  //  WIDGET HELPERS
  // ==========================================

  Widget _buildWelcomeCard(bool isTeacher) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey[700]!, Colors.blueGrey[900]!],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome back,",
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 5),
          Text(
            _currentName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isTeacher
                  ? "Instructor"
                  : "Student${widget.rollno != null ? ' | ${widget.rollno}' : ''}",
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentDashboard() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('students')
              .where(
                'roll',
                whereIn:
                    [
                      widget.rollno,
                      if (widget.rollno != null) int.tryParse(widget.rollno!),
                      widget.rollno.toString(),
                    ].where((e) => e != null).toSet().toList(),
              )
              .limit(1)
              .snapshots(),
      builder: (context, snapshot) {
        // Helper function
        Widget buildUI(Map<String, dynamic> data) {
          final studentSection = data['section'];
          // Update local name if changed in DB
          if (data['name'] != null && data['name'] != _currentName) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _currentName = data['name']);
            });
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "My Courses & Reports",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: courses.length,
                separatorBuilder: (c, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.subject, color: Colors.blueGrey[700]),
                      ),
                      title: Text(
                        courses[index],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        "Section $studentSection",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey[50],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: Colors.blueGrey,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AttendanceReportPage(
                                  role: widget.role,
                                  currentStudentRollNo: widget.rollno,
                                  initialCourse: courses[index],
                                  initialSection: studentSection,
                                ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          return buildUI(data);
        }

        // Fallback Local
        return FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, localSnapshot) {
            if (!localSnapshot.hasData) return const SizedBox();
            final prefs = localSnapshot.data!;
            final targetRoll = widget.rollno!.trim().toLowerCase();

            String? jsonUse;
            // Try exact
            jsonUse = prefs.getString('student_${widget.rollno}');
            if (jsonUse == null) {
              for (String k in prefs.getKeys()) {
                if (k.startsWith('student_') &&
                    k.substring(8).trim().toLowerCase() == targetRoll) {
                  jsonUse = prefs.getString(k);
                  break;
                }
              }
            }

            if (jsonUse != null) {
              try {
                final localData = jsonDecode(jsonUse) as Map<String, dynamic>;
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_off, color: Colors.orange),
                          SizedBox(width: 8),
                          Text("Offline Mode"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    buildUI(localData),
                  ],
                );
              } catch (e) {
                return const SizedBox();
              }
            }

            return Center(
              child: Column(
                children: [
                  Icon(Icons.person_off, size: 50, color: Colors.grey[400]),
                  const Text(
                    "Student Record Not Found",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  //  POPUP SETTINGS
  // ==========================================
  void _showProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.all(20),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profile Helper
                    GestureDetector(
                      onTap: () async {
                        await _pickImage();
                        setStateDialog(
                          () {},
                        ); // Refresh dialog to show new image
                      },
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.blueGrey,
                            backgroundImage: _getAvatarImage(),
                            child:
                                _isUploading
                                    ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                    : (_getAvatarImage() == null
                                        ? Text(
                                          _currentName.isNotEmpty
                                              ? _currentName[0].toUpperCase()
                                              : "U",
                                          style: const TextStyle(
                                            fontSize: 30,
                                            color: Colors.white,
                                          ),
                                        )
                                        : null),
                          ),
                          if (!_isUploading)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Tap to change picture",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),

                    // Name Field (READ ONLY)
                    TextFormField(
                      initialValue: _currentName,
                      readOnly: true, // USER CANNOT CHANGE NAME
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: widget.email,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Email",
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Change Password Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // Close profile dialog first
                          _showChangePasswordDialog(context);
                        },
                        icon: const Icon(Icons.lock_reset),
                        label: const Text("Change Password"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    const Divider(),

                    // Logout
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _logout(context);
                        },
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text(
                          "Logout",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
                                errorMessage = "Incorrect Current Password.";
                              } else if (e.toString().contains(
                                "weak-password",
                              )) {
                                errorMessage = "New password is too weak.";
                              } else {
                                errorMessage = e.toString();
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              if (context.mounted) {
                                setStateDialog(() => isLoading = false);
                              }
                            }
                          },
                  child: const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

extension on Container {
  get paddings => null;
}

// ==========================================
//  HOVER CARD WIDGET
// ==========================================
class HoverCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const HoverCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color:
                    _isHovered
                        ? Colors.blueGrey.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.1),
                blurRadius: _isHovered ? 12 : 5,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10), // Smaller padding
                decoration: BoxDecoration(
                  color: _isHovered ? Colors.blueGrey : Colors.blueGrey[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: 28, // Smaller icon
                  color: _isHovered ? Colors.white : Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // Smaller text
                  color: _isHovered ? Colors.blueGrey[600] : Colors.blueGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
