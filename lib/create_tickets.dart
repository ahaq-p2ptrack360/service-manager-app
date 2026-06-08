import 'package:anwar/profile.dart';
import 'package:flutter/material.dart';
import 'package:anwar/constant.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateTickets extends StatefulWidget {
  const CreateTickets({super.key});

  @override
  State<CreateTickets> createState() => _CreateTicketsState();
}

class _CreateTicketsState extends State<CreateTickets> {
  final _formKey = GlobalKey<FormState>();

  // Dropdown values
  String? reportedBy;
  String? modeOfComplaint;
  String? issueType;
  String? resolvedBy;
  String? status;
  String? priority;
  String? impact;

  bool taskAssigned = false;
  bool allowQuotation = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;

    // --- Whether lower form is active
    final bool lowerFormEnabled = taskAssigned;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xff332757),
        iconTheme: const IconThemeData(color: Colors.white),
        title:  Text(
          'P2P Track ',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          // IconButton(
          //   icon: Icon(Icons.notifications_none,
          //       size: width * 0.06, color: Colors.white),
          //   onPressed: () {},
          // ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: width * 0.1,
            height: width * 0.1,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(width * 0.05),
            ),
            child:   GestureDetector(
                child: const Icon(Icons.person_outline, color: Colors.black87),
                onTap: (){
                  Navigator.push(context, MaterialPageRoute(builder: (context)=>ProfileViewScreen(userData: {},)));
                }),
          ),
        ],
      ),
      drawer: MyDrawer(),
      body: SingleChildScrollView(
        padding:  EdgeInsets.symmetric(horizontal: 8,vertical: 25),
        child: Form(
          key: _formKey,
          child: Column(
            children: [

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(label: "Ticket #"),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                        label: "Ticket Created By",
                        readOnly: false,

                        initialValue: ""),
                  ),
                ],
              ),
              const SizedBox(height: 10),


              Row(
                children: [
                  Checkbox(
                    value: taskAssigned,
                    onChanged: (val) {
                      setState(() => taskAssigned = val ?? false);
                    },
                  ),
                   Text("Task Assigned"),
                ],
              ),

              const SizedBox(height: 10),

              // --- Ticket Reported By (enabled if taskAssigned)
              _buildDropdown(
                label: "Ticket Reported By",
                value: reportedBy,
                items: ["User A", "User B", "User C"],
                onChanged:
                lowerFormEnabled ? (v) => setState(() => reportedBy = v) : null,
                enabled: lowerFormEnabled,
              ),
              const SizedBox(height: 10),

              // --- Problem + Mode of Complaint
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                        label: "Problem",
                        hint: "Enter Problem",
                        enabled: lowerFormEnabled),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDropdown(
                      label: "Mode of Complaint",
                      value: modeOfComplaint,
                      items: ["Email", "Phone", "App"],
                      onChanged: lowerFormEnabled
                          ? (v) => setState(() => modeOfComplaint = v)
                          : null,
                      enabled: lowerFormEnabled,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // --- Issue Type + Resolved By
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: "Issue Type",
                      value: issueType,
                      items: ["Electrical", "Network", "Plumbing"],
                      onChanged: lowerFormEnabled
                          ? (v) => setState(() => issueType = v)
                          : null,
                      enabled: lowerFormEnabled,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDropdown(
                      label: "Ticket Resolved By",
                      value: resolvedBy,
                      items: ["Tech1", "Tech2", "Tech3"],
                      onChanged: lowerFormEnabled
                          ? (v) => setState(() => resolvedBy = v)
                          : null,
                      enabled: lowerFormEnabled,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),


              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                        label: "Issue Sub Type", enabled: lowerFormEnabled),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                        label: "Ticket Resolved Date",
                        hint: "Resolved Date",
                        enabled: lowerFormEnabled),
                  ),
                ],
              ),
              const SizedBox(height: 10),


              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: "Status",
                      value: status,
                      items: ["Open", "Closed", "In Progress"],
                      onChanged: lowerFormEnabled
                          ? (v) => setState(() => status = v)
                          : null,
                      enabled: lowerFormEnabled,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDropdown(
                      label: "Priority",
                      value: priority,
                      items: ["Low", "Medium", "High"],
                      onChanged: lowerFormEnabled
                          ? (v) => setState(() => priority = v)
                          : null,
                      enabled: lowerFormEnabled,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // --- Store Name + Due Date
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                        label: "BU/Store Name", enabled: lowerFormEnabled),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                        label: "Ticket Due Date",
                        hint: "Due Date",
                        enabled: lowerFormEnabled),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // --- Store Info + Impact
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                        label: "Store Info",
                        hint: "Enter Store Info",
                        enabled: lowerFormEnabled),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDropdown(
                      label: "Impact",
                      value: impact,
                      items: ["Low", "Medium", "High"],
                      onChanged: lowerFormEnabled
                          ? (v) => setState(() => impact = v)
                          : null,
                      enabled: lowerFormEnabled,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // --- Allow Quotation Checkbox
              Row(
                children: [
                  Checkbox(
                    value: allowQuotation,
                    onChanged: lowerFormEnabled
                        ? (val) => setState(() => allowQuotation = val ?? false)
                        : null,
                  ),
                   Text("Allow Quotation"),
                ],
              ),
              const SizedBox(height: 10),

              // --- Description Field (enabled only if allowQuotation)
              _buildTextField(
                label: "Description",
                maxLines: 3,
                enabled: allowQuotation && lowerFormEnabled,
              ),
              const SizedBox(height: 16),

              // --- File Upload Placeholder (active if allowQuotation)
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: allowQuotation && lowerFormEnabled
                        ? Colors.deepPurple
                        : Colors.grey,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: allowQuotation && lowerFormEnabled
                      ? Colors.deepPurple.shade50
                      : Colors.grey.shade200,
                ),
                alignment: Alignment.center,
                child: Text(
                  "Drop files here",
                  style: GoogleFonts.poppins(
                    color: allowQuotation && lowerFormEnabled
                        ? Colors.black
                        : Colors.black45,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- Save Button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff332757),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                  ),
                  onPressed: lowerFormEnabled
                      ? () {
                    if (_formKey.currentState!.validate()) {
                      // TODO: Handle save logic
                    }
                  }
                      : null,
                  child:  Text("Save",
                      style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Text Field Builder
Widget _buildTextField({
  required String label,
  String? hint,
  bool readOnly = false,
  String? initialValue,
  int maxLines = 1,
  bool enabled = true,
}) {
  return TextFormField(
    readOnly: readOnly,
    enabled: enabled,
    initialValue: initialValue,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey.shade200,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

// --- Dropdown Builder
Widget _buildDropdown({
  required String label,
  required String? value,
  required List<String> items,
  required ValueChanged<String?>? onChanged,
  bool enabled = true,
}) {
  return DropdownButtonFormField<String>(
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey.shade200,
    ),
    value: value,
    onChanged: enabled ? onChanged : null,
    items: items
        .map((e) => DropdownMenuItem(
      value: e,
      child: Text(e),
    ))
        .toList(),
  );
}





