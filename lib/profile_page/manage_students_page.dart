import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ManageStudentsPage extends StatefulWidget {
  const ManageStudentsPage({super.key});

  @override
  State<ManageStudentsPage> createState() => _ManageStudentsPageState();
}

class _ManageStudentsPageState extends State<ManageStudentsPage> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String rollNo = '';
  String section = 'A';
  String? selectedCourse;
  bool isLoading = false;
  
  final List<String> sections = ["A", "B", "C"];
  final List<String> courses = [
    "Digital Logic Design",
    "Discrete Mathematics",
    "Electrical and Electronic Engineering",
    "Humanities",
    "Mathematics",
  ];

  // Delete student
  Future<void> _deleteStudent(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('students').doc(docId).delete();
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Student Deleted")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting: $e")),
      );
    }
  }

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    if (selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a course")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Check if student already exists
      final check = await FirebaseFirestore.instance
          .collection('students')
          .where('roll', isEqualTo: int.tryParse(rollNo) ?? rollNo)
          .get();

      if (check.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Student with this Roll No already exists!")),
          );
          setState(() => isLoading = false);
          return;
      }

      // Add student
      final cleanRoll = rollNo.trim();
      
      await FirebaseFirestore.instance.collection('students').add({
        'name': name.trim(),
        'roll': int.tryParse(cleanRoll) ?? cleanRoll,
        'section': section,
        'course': selectedCourse,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // --- EMERGENCY LOCAL BACKUP ---
      try {
        final prefs = await SharedPreferences.getInstance();
        final studentData = {
          'name': name.trim(),
          'roll': cleanRoll, 
          'section': section,
          'course': selectedCourse,
        };
        // Save as "student_ROLLNO" (trimmed)
        await prefs.setString('student_$cleanRoll', jsonEncode(studentData));
        
        // Also add to global index list
        final List<String> indexList = prefs.getStringList('student_index_list') ?? [];
        if (!indexList.contains(cleanRoll)) {
           indexList.add(cleanRoll);
           await prefs.setStringList('student_index_list', indexList);
        }
        
        print("Locally saved student: student_$cleanRoll to index list"); 
      } catch (e) {
        print("Error saving locally: $e");
      }
      // ------------------------------

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Student Added Successfully!")),
      );

      _formKey.currentState!.reset();
      setState(() {
          name = '';
          rollNo = '';
          section = 'A';
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding student: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
            title: const Text("Manage Students"),
            backgroundColor: Colors.blueGrey,
        ),
        body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
                key: _formKey,
                child: Column(
                    children: [
                        Text(
                            "Add New Student",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                            decoration: InputDecoration(
                                labelText: "Student Name",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                            ),
                            validator: (v) => v!.isEmpty ? "Enter Name" : null,
                            onSaved: (v) => name = v!,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                            decoration: InputDecoration(
                                labelText: "Roll No",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.numbers),
                            ),
                            validator: (v) => v!.isEmpty ? "Enter Roll No" : null,
                            onSaved: (v) => rollNo = v!,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                            value: section,
                            decoration: InputDecoration(
                                labelText: "Section",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.class_),
                            ),
                            items: sections.map((s) => DropdownMenuItem(value: s, child: Text("Section $s"))).toList(),
                            onChanged: (v) => setState(() => section = v!),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                            value: selectedCourse,
                            decoration: InputDecoration(
                                labelText: "Course",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.book),
                            ),
                            items: courses.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => selectedCourse = v),
                            isExpanded: true,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                                onPressed: isLoading ? null : _addStudent,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                                child: isLoading 
                                    ? CircularProgressIndicator(color: Colors.white) 
                                    : Text("Add Student", style: TextStyle(color: Colors.white, fontSize: 18)),
                            ),
                        ),
                        const SizedBox(height: 30),
                        const Divider(),
                        Text(
                          "All Registered Students",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('students')
                                  .orderBy('createdAt', descending: true)
                                  .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const Center(child: Text("No students found in this section."));
                              }

                              final docs = snapshot.data!.docs;
                              // Client side sort (Mixed String/Int safety)
                              docs.sort((a, b) {
                                 final d1 = a.data() as Map<String, dynamic>;
                                 final d2 = b.data() as Map<String, dynamic>;
                                 
                                 var roll1 = d1['roll'];
                                 var roll2 = d2['roll'];
                                 
                                 // Try to compare as numbers if possible
                                 int? i1 = int.tryParse(roll1.toString());
                                 int? i2 = int.tryParse(roll2.toString());
                                 
                                 if (i1 != null && i2 != null) {
                                   return i1.compareTo(i2);
                                 }
                                 
                                 // Fallback to string comparison
                                 return roll1.toString().compareTo(roll2.toString());
                              });
                              
                              return ListView.builder(
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final data = docs[index].data() as Map<String, dynamic>;
                                  final id = docs[index].id;
                                  return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.blueGrey,
                                        child: Text(
                                          data['roll']?.toString() ?? '0',
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                      title: Text(data['name'] ?? 'Unknown'),
                                      subtitle: Text("Roll No: ${data['roll']}"),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteStudent(id),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                    ],
                ),
            ),
        ),
      );
  }
}
