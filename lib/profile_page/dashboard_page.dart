import 'package:flutter/material.dart';
import 'attendance_page.dart';
import 'reports_page.dart';
import 'schedule_page.dart';
import '../login_page/login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'profile_page.dart';
import 'manage_students_page.dart';

class DashboardPage extends StatelessWidget {
  final String name;
  final String email;
  final String role;

  const DashboardPage({
    super.key,
    required this.name,
    required this.email,
    required this.role,
    this.rollno,
  });

  final String? rollno;
  
  static const List<String> courses = [
    "Digital Logic Design",
    "Discrete Mathematics",
    "Electrical and Electronic Engineering",
    "Humanities",
    "Mathematics",
  ];

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTeacher = role.toLowerCase() == "teacher";

    return Scaffold(
      appBar: AppBar(
        title: Text(isTeacher ? "Teacher Dashboard" : "Student Dashboard"),
        backgroundColor: Colors.blueGrey[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: "Logout",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
             _buildWelcomeSection(), // Name & Email
            const SizedBox(height: 20),
            
            // Student View
            if (rollno != null && !isTeacher) 
               StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('students')
                    .where('roll', whereIn: [
                      rollno,
                      if (rollno != null) int.tryParse(rollno!),
                      rollno.toString()
                    ].where((e) => e != null).toSet().toList()) 
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Helper function to build the dashboard UI from data map
                  Widget buildDashboardUI(Map<String, dynamic> data) {
                      final studentSection = data['section'];
                      return Column(
                        children: [
                          // 1. Professional Profile Card
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                   Row(
                                     children: [
                                       CircleAvatar(
                                         backgroundColor: Colors.blueGrey,
                                         radius: 25,
                                         child: Icon(Icons.person, color: Colors.white, size: 30),
                                       ),
                                       const SizedBox(width: 15),
                                       Expanded(
                                         child: Column(
                                           crossAxisAlignment: CrossAxisAlignment.start,
                                           children: [
                                             Text(
                                                data['name'] ?? name,
                                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                             ),
                                             Text(
                                                "Roll No: ${rollno!} | Section: ${data['section'] ?? '-'}",
                                                style: TextStyle(color: Colors.grey[600]),
                                             ),
                                             if (data['course'] != null)
                                                Text(
                                                  "Program: ${data['course']}",
                                                  style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500),
                                                ),
                                           ],
                                         ),
                                       ),
                                     ],
                                   ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          
                          // 2. Actionable Course List
                          Row(
                            children: [
                              Icon(Icons.menu_book, color: Colors.blueGrey),
                              SizedBox(width: 8),
                              Text(
                                "My Attendance Reports",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: courses.length,
                            separatorBuilder: (c, i) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                               return Card(
                                 elevation: 2,
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                 child: ListTile(
                                   leading: Container(
                                     padding: const EdgeInsets.all(8),
                                     decoration: BoxDecoration(
                                       color: Colors.blueGrey[50],
                                       borderRadius: BorderRadius.circular(8),
                                     ),
                                     child: Icon(Icons.bar_chart, color: Colors.blueGrey[700]),
                                   ),
                                   title: Text(courses[index], style: const TextStyle(fontWeight: FontWeight.w600)),
                                   subtitle: Text("View attendance for Section $studentSection"),
                                   trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                   onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AttendanceReportPage(
                                            role: role,
                                            currentStudentRollNo: rollno,
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
                          
                          const SizedBox(height: 20),
                          // 3. Other Actions
                          const Divider(),
                          const SizedBox(height: 10),
                          ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: const Text("My Profile Settings"),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(
                                name: data['name'] ?? name, 
                                email: email, 
                                password: "...", 
                                roll: rollno,
                                readOnly: false
                            ))),
                          ),
                          ListTile(
                             leading: const Icon(Icons.calendar_today),
                             title: const Text("Class Schedule"),
                             onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SchedulePage())),
                          ),
                        ],
                      );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                     return const Center(child: CircularProgressIndicator());
                  }

                  // If Firestore has data, use it
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                      return buildDashboardUI(data);
                  }

                  // === FALLBACK: TRY LOCAL STORAGE (ROBUST) ===
                  return FutureBuilder<SharedPreferences>(
                    future: SharedPreferences.getInstance(),
                    builder: (context, localSnapshot) {
                       if (!localSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                       
                       final prefs = localSnapshot.data!;
                       final targetRoll = rollno!.trim().toLowerCase();
                       
                       // 1. Try Direct Match
                       String? jsonToUse = prefs.getString('student_$rollno');
                       if (jsonToUse == null) {
                           // 2. Search all keys for case-insensitive match
                           final allKeys = prefs.getKeys();
                           for (String key in allKeys) {
                               if (key.startsWith('student_')) {
                                   String storedRoll = key.substring(8); // remove 'student_'
                                   if (storedRoll.trim().toLowerCase() == targetRoll) {
                                       jsonToUse = prefs.getString(key);
                                       break;
                                   }
                               }
                           }
                       }
                       
                       if (jsonToUse != null) {
                          try {
                              final localData = jsonDecode(jsonToUse) as Map<String, dynamic>;
                              return Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    color: Colors.orange[100],
                                    child: Row(children: [
                                        const Icon(Icons.warning, color: Colors.orange), 
                                        const SizedBox(width: 8), 
                                        const Expanded(child: Text("Offline Mode: Showing Local Data", style: TextStyle(color: Colors.black87)))
                                    ]),
                                  ),
                                  const SizedBox(height: 10),
                                  buildDashboardUI(localData),
                                ],
                              );
                          } catch (e) {
                             print("Error parsing local data: $e");
                          }
                       }
                       
                       // Debugging: What keys DO we have?
                       List<String> availableStudents = [];
                       for(String k in prefs.getKeys()) {
                           if (k.startsWith('student_')) availableStudents.add(k.substring(8));
                       }

                       // If NO data anywhere
                       return Card(
                          margin: const EdgeInsets.all(16),
                          color: Colors.red[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    const Text("Student Record Not Found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                                    const SizedBox(height: 10),
                                    Text("Logged in as: '$rollno'"),
                                    const SizedBox(height: 10),
                                    const Text("We checked Firestore (Remote) and Local Storage."),
                                    const SizedBox(height: 10),
                                    if (availableStudents.isNotEmpty)
                                       Text("Found these Local Students: ${availableStudents.join(', ')}.\n\nERROR: Your Roll No '$rollno' does not match any of them.", style: const TextStyle(fontWeight: FontWeight.bold))
                                    else
                                       const Text("No local student records found.\n\nPlease log in as TEACHER -> Manage Students -> Add this roll number."),
                                ],
                            ),
                          ),
                        );
                    }
                  );
                  // ===========================================
                },
              ),

             // Teacher View (Keep existing grid or simplified)
             if (isTeacher)
                _buildTeacherDashboard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
     return Column(
       children: [
          Center(
              child: Text(
                "Welcome, $name!",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "Email: $email",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
       ]
     );
  }

  Widget _buildTeacherDashboard(BuildContext context) {
      return Column(
        children: [
             const SizedBox(height: 20),
            const Center(
              child: Text(
                "Teacher Actions",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
             Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                  children: [
                      _buildDashboardCard(
                        icon: Icons.check_circle,
                        title: "Take Attendance",
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendancePage())),
                      ),
                      _buildDashboardCard(
                        icon: Icons.people,
                        title: "Manage Students",
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageStudentsPage())),
                      ),
                      _buildDashboardCard(
                      icon: Icons.analytics,
                      title: "Reports",
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceReportPage(role: role))),
                    ),
                    _buildDashboardCard(
                      icon: Icons.calendar_today,
                      title: "Schedule",
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SchedulePage())),
                    ),
                    _buildDashboardCard(
                      icon: Icons.person, // Teacher Profile
                      title: "My Profile",
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(name: name, email: email, password: "...", readOnly: true))),
                    ),
                  ],
                ),
             ),
        ],
      );
  
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(icon, size: 40, color: Colors.blueGrey),
              SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
