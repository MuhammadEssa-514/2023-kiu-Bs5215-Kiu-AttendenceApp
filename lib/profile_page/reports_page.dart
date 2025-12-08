import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'web_file_saver.dart' if (dart.library.io) 'web_file_saver_stub.dart';
import 'package:printing/printing.dart'; // For printing and PDF preview
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AttendanceReportPage extends StatefulWidget {
  final String role;
  final String? currentStudentRollNo;
  final String? initialCourse;
  final String? initialSection;

  const AttendanceReportPage({
    super.key,
    required this.role,
    this.currentStudentRollNo,
    this.initialCourse,
    this.initialSection,
  });

  @override
  State<AttendanceReportPage> createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends State<AttendanceReportPage> {
  String? selectedCourse;
  String? selectedSection;
  bool isLoading = false;
  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = DateTime.now();

  final List<String> courses = [
    "Digital Logic Design",
    "Discrete Mathematics",
    "Electrical and Electronic Engineering",
    "Humanities",
    "Mathematics",
  ];

  final List<String> sections = ["A", "B", "C"];

  List<Map<String, dynamic>> students = [];
  Map<String, Map<String, String>> attendanceData = {};
  List<String> datesList = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Initialize with passed values if available
    selectedCourse = widget.initialCourse;
    selectedSection = widget.initialSection;
    
    if (widget.currentStudentRollNo != null) {
      if (selectedCourse != null && selectedSection != null) {
          // If we already have everything (from Dashboard), generate immediately
          WidgetsBinding.instance.addPostFrameCallback((_) {
             _fetchStudents().then((_) => _generateReport());
          });
      } else {
         _autoLoadStudentDetails();
      }
    }
  }

  Future<void> _autoLoadStudentDetails() async {
    final roll = widget.currentStudentRollNo!;
    final rollInt = int.tryParse(roll);
    
    try {
        QuerySnapshot q;
        // Try finding by int roll first (as stored by ManageStudentsPage)
        if (rollInt != null) {
            q = await _firestore.collection('students').where('roll', isEqualTo: rollInt).get();
            // Fallback to string if not found
            if (q.docs.isEmpty) {
                 q = await _firestore.collection('students').where('roll', isEqualTo: roll).get();
            }
        } else {
             q = await _firestore.collection('students').where('roll', isEqualTo: roll).get();
        }

        if (q.docs.isNotEmpty) {
            final data = q.docs.first.data() as Map<String, dynamic>;
            if (mounted) {
              setState(() {
                  if (data['section'] != null) selectedSection = data['section'];
                  if (data['course'] != null) selectedCourse = data['course'];
              });
              
              if (selectedSection != null) {
                 await _fetchStudents();
                 if (selectedCourse != null) {
                    _generateReport();
                 }
              }
            }
        } else {
           // --- OFFLINE AUTO LOAD ---
           try {
             final prefs = await SharedPreferences.getInstance();
             final cleanRoll = roll.trim();
             final localJson = prefs.getString('student_$cleanRoll');
             if (localJson != null) {
                final data = jsonDecode(localJson) as Map<String, dynamic>;
                if (mounted) {
                   setState(() {
                      if (data['section'] != null) selectedSection = data['section'];
                      if (data['course'] != null) selectedCourse = data['course'];
                   });
                   if (selectedSection != null) {
                       await _fetchStudents();
                       if (selectedCourse != null) {
                          _generateReport();
                       }
                   }
                }
             }
           } catch (e) {
             print("Error offline auto-load: $e");
           }
           // -------------------------
        }
    } catch (e) {
        print("Error auto-loading student details: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTeacher = widget.role.toLowerCase() == "teacher";
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;
    final double cardPadding = isSmallScreen ? 16 : 24;
    final double cardFontSize = isSmallScreen ? 16 : 18;
    final double buttonFontSize = isSmallScreen ? 16 : 15;
    final double buttonHeight = isSmallScreen ? 48 : 40;
    final double maxContentWidth = isSmallScreen ? double.infinity : 700;
    final double dropdownFontSize = isSmallScreen ? 16 : 15;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Reports", style: const TextStyle(
            color: Colors.white,
          ),),
        backgroundColor: Colors.blueGrey,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Generate Attendance Report",
                            style: TextStyle(
                              fontSize: cardFontSize + 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: selectedCourse,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: "Select Course",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: dropdownFontSize,
                                    color: Colors.black,
                                  ),
                                  items:
                                      courses.map((course) {
                                        return DropdownMenuItem(
                                          value: course,
                                          child: Text(
                                            course,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setState(() => selectedCourse = value);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: selectedSection,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: "Select Section",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: dropdownFontSize,
                                    color: Colors.black,
                                  ),
                                  items:
                                      sections.map((section) {
                                        return DropdownMenuItem(
                                          value: section,
                                          child: Text(section),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedSection = value;
                                      _fetchStudents();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Start Date"),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () => _selectDate(context, true),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              DateFormat(
                                                'yyyy-MM-dd',
                                              ).format(startDate),
                                            ),
                                            const Icon(Icons.calendar_today),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("End Date"),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () => _selectDate(context, false),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              DateFormat(
                                                'yyyy-MM-dd',
                                              ).format(endDate),
                                            ),
                                            const Icon(Icons.calendar_today),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: buttonHeight + 4,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        isLoading ? null : _generateReport,
                                    icon: const Icon(Icons.refresh),
                                    label: Text(
                                      "Generate Report",
                                      style: TextStyle(
                                        fontSize: buttonFontSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.cyan.shade500,
                                      foregroundColor: Colors.white,
                                      elevation: 4,
                                      minimumSize: Size(
                                        double.infinity,
                                        buttonHeight + 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: buttonHeight + 4,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        (attendanceData.isEmpty ||
                                                isLoading ||
                                                !isTeacher)
                                            ? null
                                            : _exportToExcel,
                                    icon: const Icon(Icons.table_chart),
                                    label: Text(
                                      "Export to Excel",
                                      style: TextStyle(
                                        fontSize: buttonFontSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      foregroundColor: Colors.white,
                                      elevation: 4,
                                      minimumSize: Size(
                                        double.infinity,
                                        buttonHeight + 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: buttonHeight + 4,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        (attendanceData.isEmpty ||
                                                isLoading ||
                                                !isTeacher)
                                            ? null
                                            : _exportToPdf,
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: Text(
                                      "Export to PDF",
                                      style: TextStyle(
                                        fontSize: buttonFontSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      foregroundColor: Colors.white,
                                      elevation: 4,
                                      minimumSize: Size(
                                        double.infinity,
                                        buttonHeight + 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // PRINT BUTTON - Everyone
                          ElevatedButton.icon(
                            icon: const Icon(Icons.print, size: 30),
                            label: const Text(
                              "Print Report",
                              style: TextStyle(fontSize: 20),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[800],
                              foregroundColor: Colors.white,
                              elevation: 4,
                              minimumSize: Size(double.infinity, 60),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _printReport,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child:
                        isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : (attendanceData.isEmpty)
                            ? const Center(
                              child: Text(
                                "No data to display.\nPlease select course, section and date range and generate report.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                            : Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(cardPadding),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      "Attendance Report: $selectedCourse - Section $selectedSection",
                                      style: TextStyle(
                                        fontSize: cardFontSize + 2,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "Period: [${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}]",
                                      style: TextStyle(
                                        fontSize: cardFontSize - 2,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: SingleChildScrollView(
                                          child: _buildAttendanceTable(),
                                        ),
                                      ),
                                    ),
                                  ],
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

  // ALL YOUR ORIGINAL METHODS BELOW — COPY FROM YOUR OLD FILE
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? startDate : endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
          if (startDate.isAfter(endDate)) endDate = startDate;
        } else {
          endDate = picked;
          if (endDate.isBefore(startDate)) startDate = endDate;
        }
      });
    }
  }

  Future<void> _fetchStudents() async {
    if (selectedSection == null) return;
    setState(() {
      isLoading = true;
      students.clear();
    });
    try {
      final querySnapshot =
          await _firestore
              .collection('students')
              .where('section', isEqualTo: selectedSection)
              .get();
      
      var fetchedStudents = <Map<String, dynamic>>[];
      
      if (querySnapshot.docs.isNotEmpty) {
         fetchedStudents = querySnapshot.docs.map((doc) {
              final data = doc.data();
              return {
                "rollNo": data['roll'] ?? 0,
                "id": data['roll']?.toString() ?? '0',
                "name": data['name'] ?? 'Unknown',
              };
         }).toList();
      } else {
         // --- OFFLINE FETCH STUDENTS ---
         final prefs = await SharedPreferences.getInstance();
         final indexList = prefs.getStringList('student_index_list') ?? [];
         
         for (var roll in indexList) {
            final jsonStr = prefs.getString('student_$roll');
            if (jsonStr != null) {
               final data = jsonDecode(jsonStr) as Map<String, dynamic>;
               if (data['section'] == selectedSection) {
                   fetchedStudents.add({
                     "rollNo": roll, 
                     "id": roll,
                     "name": data['name'] ?? 'Unknown',
                   });
               }
            }
         }
         // ------------------------------
      }

      setState(() {

        // Client-side sort
        fetchedStudents.sort((a, b) {
           int r1 = int.tryParse(a['id'].toString()) ?? 0;
           int r2 = int.tryParse(b['id'].toString()) ?? 0;
           return r1.compareTo(r2);
        });

        // If student role, filter by own roll number
        if (widget.currentStudentRollNo != null) {
            fetchedStudents = fetchedStudents.where((s) => s['id'] == widget.currentStudentRollNo).toList();
        }

        students = fetchedStudents;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error fetching students: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _generateReport() async {
    if (selectedCourse == null || selectedSection == null || students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select course and section first")),
      );
      return;
    }

    setState(() {
      isLoading = true;
      attendanceData.clear();
      datesList.clear();
    });

    try {
      List<DateTime> datesInRange = [];
      for (
        DateTime date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))
      ) {
        datesInRange.add(date);
      }
      datesList =
          datesInRange
              .map((date) => DateFormat('yyyy-MM-dd').format(date))
              .toList();

      for (var student in students) {
        attendanceData[student['id']] = {};
        for (var dateStr in datesList) {
          attendanceData[student['id']]![dateStr] = '-';
        }
      }

      final List<Future<void>> fetchFutures = [];
      for (var dateStr in datesList) {
        fetchFutures.add(
          _firestore
              .collection('attendance_records')
              .doc(dateStr)
              .collection('sections')
              .doc(selectedSection)
              .collection('rolls')
              .get()
              .then((rollsSnapshot) async {
                if (rollsSnapshot.docs.isEmpty) return;
                final List<Future<void>> courseFutures = [];
                for (var rollDoc in rollsSnapshot.docs) {
                  final rollNo = rollDoc.id;
                  courseFutures.add(
                    rollDoc.reference
                        .collection('courses')
                        .doc(selectedCourse)
                        .get()
                        .then((courseDoc) {
                          if (courseDoc.exists) {
                            String status = courseDoc.data()?['status'] ?? '-';
                            if (attendanceData.containsKey(rollNo)) {
                              attendanceData[rollNo]![dateStr] =
                                  status == 'Present' ? 'P' : 'A';
                            }
                          }
                        }),
                  );
                }
                await Future.wait(courseFutures);
              }),
        );
      }
      await Future.wait(fetchFutures);
      
      // --- OFFLINE REPORT GENERATION ---
      try {
           final prefs = await SharedPreferences.getInstance();
           final records = prefs.getStringList('attendance_records') ?? [];
           
           for (var jsonStr in records) {
               final r = jsonDecode(jsonStr) as Map<String, dynamic>;
               final rDate = r['date'];
               final rCourse = r['course'];
               final rRoll = r['roll'];
               final rStatus = r['status'];
               
               if (rCourse == selectedCourse && datesList.contains(rDate)) {
                   if (attendanceData.containsKey(rRoll)) {
                        attendanceData[rRoll]![rDate] = (rStatus == 'Present' ? 'P' : 'A');
                   }
               }
           }
      } catch (e) {
          print("Error generating offline report: $e");
      }
      // ---------------------------------

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error generating report: $e")));
    }
  }

  Map<String, double> _calculateAttendancePercentages() {
    Map<String, double> percentages = {};
    for (var student in students) {
      String studentId = student['id'] ?? '';
      if (studentId.isEmpty) continue;
      int presentCount = 0;
      int totalSessions = 0;
      for (var dateStr in datesList) {
        String status = attendanceData[studentId]?[dateStr] ?? '-';
        if (status == 'P' || status == 'A') {
          totalSessions++;
          if (status == 'P') presentCount++;
        }
      }
      double percentage =
          totalSessions > 0 ? (presentCount / totalSessions) * 100 : 0.0;
      percentages[studentId] = percentage;
    }
    return percentages;
  }

  Widget _buildAttendanceTable() {
    final percentages = _calculateAttendancePercentages();

    return DataTable(
      columnSpacing: 12,
      headingRowColor: WidgetStateProperty.all(Colors.blueGrey[100]),
      border: TableBorder.all(color: Colors.grey.shade300),
      columns: [
        const DataColumn(
          label: Text('Roll', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const DataColumn(
          label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...datesList.map(
          (dateStr) => DataColumn(
            label: SizedBox(
              width: 75,
              child: Text(
                dateStr.substring(5),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const DataColumn(
          label: Text(
            'Attendance %',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
      rows:
          students.map((student) {
            final studentId = student['id'] ?? '';
            final percentage = percentages[studentId] ?? 0.0;
            return DataRow(
              cells: [
                DataCell(Text(studentId)),
                DataCell(Text(student['name'] ?? 'Unknown')),
                ...datesList.map((dateStr) {
                  final status = attendanceData[studentId]?[dateStr] ?? '-';
                  return DataCell(
                    Center(
                      child: Text(
                        status,
                        style: TextStyle(
                          color:
                              (status == 'P')
                                  ? Colors.green
                                  : ((status == 'A')
                                      ? Colors.red
                                      : Colors.grey),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
                DataCell(
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: percentage >= 50 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }

  Future<void> _exportToExcel() async {
    final excel = excel_lib.Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Headers
    List<String> headers = ['Roll No', 'Name', ...datesList.map((d) => d.substring(5)), 'Percentage'];
    sheet.appendRow(headers.map((e) => excel_lib.TextCellValue(e)).toList());

    final percentages = _calculateAttendancePercentages();

    for (var student in students) {
      List<excel_lib.CellValue> row = [];
      String id = student['id'] ?? '';
      row.add(excel_lib.TextCellValue(id));
      row.add(excel_lib.TextCellValue(student['name'] ?? 'Unknown'));

      for (var dateStr in datesList) {
        row.add(excel_lib.TextCellValue(attendanceData[id]?[dateStr] ?? '-'));
      }
      
      double pct = percentages[id] ?? 0.0;
      row.add(excel_lib.TextCellValue('${pct.toStringAsFixed(1)}%'));
      
      sheet.appendRow(row);
    }

    // Save file
    final List<int>? fileBytes = excel.save();
    if (fileBytes != null) {
      if (kIsWeb) {
         final webSaver = WebFileSaver();
         await webSaver.saveFile(Uint8List.fromList(fileBytes), "attendance_report.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
      } else {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Excel File',
          fileName: 'attendance_report.xlsx',
          allowedExtensions: ['xlsx'],
          type: FileType.custom,
        );
        if (outputFile != null) {
           File(outputFile)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes);
           OpenFile.open(outputFile);
        }
      }
    }
  }

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();
    final percentages = _calculateAttendancePercentages();
    
    // Chunking data if too many columns (simple approach: just put all in one big table)
    // For PDF, better to limit columns or use landscape.
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return [
             pw.Header(level: 0, child: pw.Text("Attendance Report: $selectedCourse - $selectedSection")),
             pw.Paragraph(text: "From ${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}"),
             pw.Table.fromTextArray(
                context: context,
                headers: ['Roll', 'Name', ...datesList.map((d) => d.substring(5)), '%'],
                data: students.map((student) {
                   String id = student['id'] ?? '';
                   double pct = percentages[id] ?? 0.0;
                   return [
                     id,
                     student['name'] ?? 'Unknown',
                     ...datesList.map((d) => attendanceData[id]?[d] ?? '-'),
                     '${pct.toStringAsFixed(1)}%'
                   ];
                }).toList(),
             ),
          ];
        }
      )
    );

    final Uint8List bytes = await pdf.save();

     if (kIsWeb) {
         final webSaver = WebFileSaver();
         await webSaver.saveFile(bytes, "attendance_report.pdf", "application/pdf");
      } else {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save PDF File',
          fileName: 'attendance_report.pdf',
          allowedExtensions: ['pdf'],
          type: FileType.custom,
        );
         if (outputFile != null) {
           File(outputFile)
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes);
           OpenFile.open(outputFile);
        }
      }
  }
  
  Future<void> _printReport() async {
     final pdf = pw.Document();
    final percentages = _calculateAttendancePercentages();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return [
             pw.Header(level: 0, child: pw.Text("Attendance Report: $selectedCourse - $selectedSection")),
             pw.Paragraph(text: "From ${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}"),
             pw.Table.fromTextArray(
                context: context,
                headers: ['Roll', 'Name', ...datesList.map((d) => d.substring(5)), '%'],
                data: students.map((student) {
                   String id = student['id'] ?? '';
                   double pct = percentages[id] ?? 0.0;
                   return [
                     id,
                     student['name'] ?? 'Unknown',
                     ...datesList.map((d) => attendanceData[id]?[d] ?? '-'),
                     '${pct.toStringAsFixed(1)}%'
                   ];
                }).toList(),
             ),
          ];
        }
      )
    );
    
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
