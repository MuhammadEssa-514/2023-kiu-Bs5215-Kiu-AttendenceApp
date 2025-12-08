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
      backgroundColor: Colors.grey[50], // Lighter background
      appBar: AppBar(
        title: const Text("Manage Students", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[800],
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. COMPACT DASHBOARD-STYLE HEADER / FORM
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
              ],
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Text("Register New Student", style: TextStyle(color: Colors.blueGrey[800], fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 15),
                   
                   // ROW 1: Name + Roll No (50% - 50%)
                   Row(
                     children: [
                       Expanded(
                         flex: 3,
                         child: TextFormField(
                           decoration: InputDecoration(
                             labelText: "Student Name",
                             prefixIcon: const Icon(Icons.person, size: 20),
                             filled: true,
                             fillColor: Colors.grey[100],
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                             contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                           ),
                           validator: (v) => v!.isEmpty ? "Required" : null,
                           onSaved: (v) => name = v!,
                         ),
                       ),
                       const SizedBox(width: 10),
                       Expanded(
                         flex: 2,
                         child: TextFormField(
                           decoration: InputDecoration(
                             labelText: "Roll No",
                             prefixIcon: const Icon(Icons.numbers, size: 20),
                             filled: true,
                             fillColor: Colors.grey[100],
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                             contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                           ),
                           validator: (v) => v!.isEmpty ? "Req" : null,
                           onSaved: (v) => rollNo = v!,
                           keyboardType: TextInputType.number,
                         ),
                       ),
                     ],
                   ),
                   
                   const SizedBox(height: 10),
                   
                   // ROW 2: Section + Course (30% - 70%)
                   Row(
                     children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: section,
                            decoration: InputDecoration(
                              labelText: "Sec",
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            items: sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setState(() => section = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<String>(
                            value: selectedCourse,
                            decoration: InputDecoration(
                              labelText: "Select Course",
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            items: courses.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setState(() => selectedCourse = v),
                            isExpanded: true,
                          ),
                        ),
                     ],
                   ),
                   
                   const SizedBox(height: 15),
                   
                   SizedBox(
                     height: 45,
                     child: ElevatedButton.icon(
                       onPressed: isLoading ? null : _addStudent,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.blueGrey[700],
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                         elevation: 2,
                       ),
                       icon: isLoading ? const SizedBox() : const Icon(Icons.add_circle, color: Colors.white),
                       label: isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text("Add Student to Database", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                     ),
                   ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 10),
          
          // 2. SCROLLABLE LIST HEADLINE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Registered Students", style: TextStyle(color: Colors.blueGrey[800], fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blueGrey[100], borderRadius: BorderRadius.circular(8)),
                  child: const Text("Sort: Newest", style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
                )
              ],
            ),
          ),
          
          const SizedBox(height: 5),

          // 3. EXPANDED LIST
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.school, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text("No students added yet.", style: TextStyle(color: Colors.grey[400])),
                      ],
                    )
                  );
                }

                // Client-side sort if needed, or use stream order
                final docs = snapshot.data!.docs;
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    
                    return Dismissible(
                      key: Key(docId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.centerRight,
                        child: const Icon(Icons.delete, color: Colors.red),
                      ),
                      confirmDismiss: (dir) async {
                         return await showDialog(
                           context: context,
                           builder: (ctx) => AlertDialog(
                             title: const Text("Delete Student?"),
                             content: Text("Are you sure you want to delete ${data['name']}?"),
                             actions: [
                               TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                               TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                             ],
                           )
                         );
                      },
                      onDismissed: (_) => _deleteStudent(docId),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 5, offset: const Offset(0, 2))]
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey[50],
                            foregroundColor: Colors.blueGrey[700],
                            child: Text(data['section'] ?? "?", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(4)),
                                child: Text("Roll: ${data['roll']}", style: TextStyle(fontSize: 11, color: Colors.blueGrey[800], fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(data['course'] ?? "", overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey))),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                            onPressed: () => _deleteStudent(docId), // Trigger delete manually too
                          ),
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
    );
  }
}
