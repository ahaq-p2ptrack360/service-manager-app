import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'dart:io';  // ✅ IMPORTANT - File class ke liye
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';

// ✅ Conditional import for web
// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html if (dart.library.html) 'package:universal_html/html.dart';

class CompanyProfile extends StatefulWidget {
const CompanyProfile({super.key});

@override
State<CompanyProfile> createState() => _CompanyProfileState();
}

class _CompanyProfileState extends State<CompanyProfile> {
late GoogleMapController _mapController;
LatLng? _companyLocation;
final Set<Marker> _markers = {};

// Company data from API
Map<String, dynamic>? _companyData;
bool _isLoading = true;
bool _hasError = false;

// Subscription packages data
List<dynamic> _subscriptionPackages = [];
bool _isLoadingPackages = false;
Map<String, dynamic>? _currentPlan;

// Store the last upgraded plan ID locally
int? _storedPlanId;

// Invoice data from API
List<Map<String, dynamic>> invoices = [];
bool _isLoadingInvoices = false;
String? _companyId;
String? _invoiceErrorMessage;

final List<Map<String, dynamic>> activities = [
{
'time': 'Today, 10:30 AM',
'action': 'John Smith updated subscription plan to Premium',
'icon': Icons.upgrade,
'color': Colors.blue,
},
{
'time': 'Yesterday, 3:45 PM',
'action': 'Sarah Johnson added 5 new employee licenses',
'icon': Icons.person_add,
'color': Colors.green,
},
{
'time': 'Dec 15, 2024',
'action': 'Company profile information was updated',
'icon': Icons.edit,
'color': Colors.purple,
},
];

@override
void initState() {
super.initState();
_loadStoredPlan();
_loadCompanyId();
_fetchCompanyProfile();
_fetchSubscriptionPackages();
}

// Load company ID from SharedPreferences
Future<void> _loadCompanyId() async {
try {
final prefs = await SharedPreferences.getInstance();

// ✅ Pehle company_id check karein (yeh correct hai)
String? companyId = prefs.getString("company_id");

// Agar nahi hai toh user_id se fetch karein
if (companyId == null || companyId.isEmpty) {
String? userId = prefs.getString("id");

if (userId != null && userId.isNotEmpty) {
print('🔍 Fetching company_id from user API for user_id: $userId');

final userResponse = await http.get(
Uri.parse('https://demo.p2ptrack360.com:8888/api/users/$userId'),
headers: {'Accept': 'application/json'},
);

if (userResponse.statusCode == 200) {
final List<dynamic> userData = json.decode(userResponse.body);

if (userData.isNotEmpty) {
// ✅ company_id extract karein
companyId = userData[0]['company_id']?.toString();

if (companyId != null && companyId.isNotEmpty) {
// ✅ Save for future use
await prefs.setString("company_id", companyId);
print('✅ Company ID saved: $companyId');
}
}
}
}
}

setState(() {
_companyId = companyId;
});


} catch (e) {
print('Error loading company ID: $e');
setState(() {
_companyId = null;
});
}
}

// Load the stored plan ID from SharedPreferences
Future<void> _loadStoredPlan() async {
try {
final prefs = await SharedPreferences.getInstance();
final storedPlanId = prefs.getInt('last_upgraded_plan_id');

if (storedPlanId != null) {
setState(() {
_storedPlanId = storedPlanId;
});
}
} catch (e) {
print('Error loading stored plan: $e');
}
}

// Store the upgraded plan ID locally
Future<void> _storeUpgradedPlanId(int planId) async {
try {
final prefs = await SharedPreferences.getInstance();
await prefs.setInt('last_upgraded_plan_id', planId);

setState(() {
_storedPlanId = planId;
});
} catch (e) {
print('Error storing upgraded plan: $e');
}
}

Future<void> _fetchInvoices() async {
// Ensure company_id is loaded
if (_companyId == null || _companyId!.isEmpty) {
print('Company ID not available yet');
setState(() {
_invoiceErrorMessage = 'Company ID not available';
_isLoadingInvoices = false;
});
return;
}

setState(() {
_isLoadingInvoices = true;
_invoiceErrorMessage = null;
});

try {
// ✅ Use company_id in API URL
final apiUrl = 'https://demo.p2ptrack360.com:8888/api/companies/$_companyId/invoices';
print('Fetching invoices from: $apiUrl');

final response = await http.get(
Uri.parse(apiUrl),
headers: {
'Accept': 'application/json',
'Content-Type': 'application/json',
},
);

print('Invoice API Response Status: ${response.statusCode}');

if (response.statusCode == 200) {
final dynamic responseData = json.decode(response.body);
List<dynamic> invoiceData = [];

if (responseData == null) {
invoiceData = [];
}
else if (responseData is List) {
invoiceData = responseData;
}
else if (responseData is Map<String, dynamic>) {
if (responseData.containsKey('response')) {
invoiceData = responseData['response'] is List ? responseData['response'] : [];
}
else if (responseData.containsKey('data')) {
invoiceData = responseData['data'] is List ? responseData['data'] : [];
}
else if (responseData.containsKey('invoices')) {
invoiceData = responseData['invoices'] is List ? responseData['invoices'] : [];
}
else {
invoiceData = [];
}
}

setState(() {
if (invoiceData.isEmpty) {
_invoiceErrorMessage = 'No invoices found for this company';
invoices = [];
} else {
invoices = invoiceData.map((invoice) {
Color statusColor;
String status = invoice['status']?.toString().toLowerCase() ?? '';

if (status == 'paid' || status == 'Paid' || status == 'PAID') {
statusColor = Colors.green;
} else if (status == 'pending' || status == 'Pending' || status == 'PENDING') {
statusColor = Colors.orange;
} else if (status == 'overdue' || status == 'Overdue' || status == 'OVERDUE') {
statusColor = Colors.red;
} else if (status == 'cancelled' || status == 'Cancelled' || status == 'CANCELLED') {
statusColor = Colors.grey;
} else {
statusColor = Colors.grey;
}

String invoiceNumber = invoice['invoice_number']?.toString() ??
invoice['id']?.toString() ??
'N/A';

String date = invoice['date']?.toString() ??
invoice['created_at']?.toString().split('T')[0] ??
'N/A';

String amount = invoice['amount']?.toString() ?? '0.00';
if (!amount.startsWith('\$')) {
amount = '\$$amount';
}

double paidAmount = invoice['paid_amount'] != null
? double.tryParse(invoice['paid_amount'].toString()) ?? 0
    : 0;

String dueDate = invoice['due_date']?.toString() ?? 'N/A';

String subscriptionType = invoice['project_name']?.toString() ??
invoice['subscription_type']?.toString() ??
invoice['plan_name']?.toString() ??
'N/A';

String companyName = invoice['company_name']?.toString() ??
invoice['company']?.toString() ??
invoice['client_name']?.toString() ??
'N/A';

return {
'invoice': invoiceNumber,
'date': date,
'amount': amount,
'amount_raw': double.tryParse(amount.replaceAll('\$', '')) ?? 0,
'paid_amount': paidAmount,
'status': invoice['status']?.toString() ?? 'Unknown',
'dueDate': dueDate,
'statusColor': statusColor,
'subscriptionType': subscriptionType,
'companyName': companyName,
'id': invoice['id'],
};
}).toList();
_invoiceErrorMessage = null;
}
});
} else {
print('Failed to load invoices: ${response.statusCode}');
setState(() {
_invoiceErrorMessage = 'Failed to load invoices (Status: ${response.statusCode})';
invoices = [];
});
}
} catch (e) {
print('Error fetching invoices: $e');
setState(() {
_invoiceErrorMessage = 'Error: ${e.toString()}';
invoices = [];
});
} finally {
setState(() {
_isLoadingInvoices = false;
});
}
}

Future<void> _fetchCompanyProfile() async {
setState(() {
_isLoading = true;
_hasError = false;
});

try {
var prefs = await SharedPreferences.getInstance();

// ✅ IMPORTANT: company_id lein, user_id nahi
String? companyId = prefs.getString("company_id");

// Agar company_id nahi hai toh load karein
if (companyId == null || companyId.isEmpty) {
await _loadCompanyId();
companyId = _companyId;
}

if (companyId == null || companyId.isEmpty) {
print('❌ No company ID found');
setState(() {
_hasError = true;
_isLoading = false;
});
return;
}


// ✅ CORRECT API URL - company_id ke saath
final apiUrl = 'https://demo.p2ptrack360.com:8888/api/companyprofile/$companyId';
print('🔍 Calling API: $apiUrl');

final response = await http.get(
Uri.parse(apiUrl),
headers: {
'Accept': 'application/json',
'Content-Type': 'application/json',
},
);

print('🔍 API Response Status: ${response.statusCode}');
print('🔍 API Response Body: ${response.body}');

if (response.statusCode == 200) {
final jsonResponse = json.decode(response.body);

Map<String, dynamic>? companyData;

// Handle response structure
if (jsonResponse['response'] is List && jsonResponse['response'].isNotEmpty) {
companyData = jsonResponse['response'][0];
} else if (jsonResponse is List && jsonResponse.isNotEmpty) {
companyData = jsonResponse[0];
} else if (jsonResponse is Map<String, dynamic>) {
if (jsonResponse.containsKey('data')) {
companyData = jsonResponse['data'];
} else if (jsonResponse.containsKey('id')) {
companyData = jsonResponse;
}
}

if (companyData != null && companyData.isNotEmpty) {
print('✅ Company found: ${companyData['name']}');

setState(() {
_companyData = companyData;
_initializeMapLocation();
_matchCurrentPlan();
});

await _fetchInvoices();

setState(() {
_isLoading = false;
});
} else {
print('❌ No company data found');
setState(() {
_hasError = true;
_isLoading = false;
});
}
} else {
print('❌ API failed: ${response.statusCode}');
setState(() {
_hasError = true;
_isLoading = false;
});
}
} catch (e) {
print('Error fetching company profile: $e');
setState(() {
_hasError = true;
_isLoading = false;
});
}
}

Future<void> _fetchSubscriptionPackages() async {
setState(() {
_isLoadingPackages = true;
});

try {
final response = await http.get(
Uri.parse('https://demo.p2ptrack360.com:8888/api/subscription-packages'),
headers: {
'Accept': 'application/json',
'Content-Type': 'application/json',
},
);

if (response.statusCode == 200) {
final List<dynamic> packages = json.decode(response.body);
setState(() {
_subscriptionPackages = packages;
_matchCurrentPlan();
});
} else {
print('Failed to load subscription packages: ${response.statusCode}');
}
} catch (e) {
print('Error fetching subscription packages: $e');
} finally {
setState(() {
_isLoadingPackages = false;
});
}
}

void _matchCurrentPlan() {
if (_companyData != null && _subscriptionPackages.isNotEmpty) {
int? planIdToUse = _storedPlanId ?? _companyData!['subscription_package_id'];

if (planIdToUse != null) {
for (var package in _subscriptionPackages) {
if (package['id'] == planIdToUse) {
setState(() {
_currentPlan = package;
});
return;
}
}
}

if (_subscriptionPackages.isNotEmpty) {
setState(() {
_currentPlan = _subscriptionPackages[0];
});
}
} else if (_subscriptionPackages.isNotEmpty && _currentPlan == null) {
setState(() {
_currentPlan = _subscriptionPackages[0];
});
}
}

void _updateCurrentPlan(Map<String, dynamic> newPlan) {
setState(() {
_currentPlan = newPlan;
});
}

void _initializeMapLocation() {
if (_companyData != null) {
try {
final lat = double.tryParse(_companyData!['latitude'] ?? '34.0522');
final lng = double.tryParse(_companyData!['longitude'] ?? '-118.2437');

_companyLocation = LatLng(
lat ?? 34.0522,
lng ?? -118.2437,
);

_markers.clear();
_markers.add(
Marker(
markerId: const MarkerId('company_location'),
position: _companyLocation!,
infoWindow: InfoWindow(
title: _companyData!['name'] ?? 'Tech Solutions Inc',
snippet: '${_companyData!['city_id'] ?? 'Los Angeles'}, ${_companyData!['state_id'] ?? 'CA'}, ${_companyData!['country_id'] ?? 'UAE'}',
),
icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
),
);
} catch (e) {
print('Error initializing map location: $e');
_companyLocation = const LatLng(34.0522, -118.2437);
}
}
}

String _getCompanyAddress() {
if (_companyData == null) return 'Los Angeles, CA, UAE';

final address1 = _companyData!['address_1'] ?? '';
final address2 = _companyData!['address_2'] ?? '';
final city = _companyData!['city_id'] ?? 'Los Angeles';
final state = _companyData!['state_id'] ?? 'CA';
final country = _companyData!['country_id'] ?? 'UAE';

if (address1.isNotEmpty && address2.isNotEmpty) {
return '$address1, $address2, $city, $state, $country';
} else if (address1.isNotEmpty) {
return '$address1, $city, $state, $country';
} else {
return '$city, $state, $country';
}
}

String _getContactPerson() {
if (_companyData == null) return 'Jane Smith';

final firstName = _companyData!['first_name'] ?? '';
final lastName = _companyData!['last_name'] ?? '';

if (firstName.isNotEmpty && lastName.isNotEmpty) {
return '$firstName $lastName';
} else if (firstName.isNotEmpty) {
return firstName;
} else {
return 'John Doe';
}
}

String _getEstablishedDate() {
if (_companyData == null) return 'Jan 02, 2025';

final createdAt = _companyData!['created_at'] ?? '';
if (createdAt.isNotEmpty) {
try {
final dateTime = DateTime.parse(createdAt);
final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
final month = months[dateTime.month - 1];
final day = dateTime.day.toString().padLeft(2, '0');
final year = dateTime.year.toString();
return '$month $day, $year';
} catch (e) {
return 'Jan 02, 2025';
}
}
return 'Jan 02, 2025';
}

String _getRenewalDate() {
final now = DateTime.now();
final renewalDate = now.add(const Duration(days: 30));
final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
final month = months[renewalDate.month - 1];
final day = renewalDate.day.toString().padLeft(2, '0');
final year = renewalDate.year.toString();
return '$month $day, $year';
}

List<Map<String, dynamic>> get _topCards {
if (_companyData == null) {
return [
{
'title': 'Total Employees',
'value': '156',
'icon': Icons.people,
'color': Colors.blue,
'change': '+12%',
'changeColor': Colors.green,
},
{
'title': 'Active Projects',
'value': '24',
'icon': Icons.work,
'color': Colors.green,
'change': '+5%',
'changeColor': Colors.green,
},
{
'title': 'Revenue',
'value': '\$45.2K',
'icon': Icons.attach_money,
'color': Colors.purple,
'change': '+18%',
'changeColor': Colors.green,
},
{
'title': 'Pending Tasks',
'value': '8',
'icon': Icons.task,
'color': Colors.orange,
'change': '-2%',
'changeColor': Colors.red,
},
];
}

return [
{
'title': 'Total Employees',
'value': _companyData!['users']?.toString() ?? '14',
'icon': Icons.people,
'color': Colors.blue,
'change': '+12%',
'changeColor': Colors.green,
},
{
'title': 'Business Units',
'value': _companyData!['total_bu']?.toString() ?? '3',
'icon': Icons.business,
'color': Colors.green,
'change': '+5%',
'changeColor': Colors.green,
},
{
'title': 'Total Tickets',
'value': _companyData!['total_tickets']?.toString() ?? '356',
'icon': Icons.support_agent,
'color': Colors.purple,
'change': '+8%',
'changeColor': Colors.green,
},
{
'title': 'Licenses',
'value': _companyData!['licences']?.toString() ?? '1',
'icon': Icons.verified,
'color': Colors.orange,
'change': 'Active',
'changeColor': Colors.green,
},
];
}

// ==================== COMPLETE WORKING DOWNLOAD (NO NEW TAB ON WEB) ====================

Future<void> _downloadInvoice(Map<String, dynamic> invoice) async {
int invoiceId = invoice['id'];
String invoiceNumber = invoice['invoice'];
String fileName = 'invoice_${invoiceNumber.replaceAll('/', '_')}.pdf';
String downloadUrl = 'https://demo.p2ptrack360.com:8888/api/invoices/$invoiceId/download-pdf';

// Show loading dialog
showDialog(
context: context,
barrierDismissible: false,
builder: (context) => AlertDialog(
content: Column(
mainAxisSize: MainAxisSize.min,
children: [
const CircularProgressIndicator(),
const SizedBox(height: 20),
Text('Downloading PDF...', style: GoogleFonts.poppins()),
const SizedBox(height: 10),
Text('Please wait...', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
],
),
),
);

try {
if (kIsWeb) {
// ========== WEB PLATFORM - BACKGROUND DOWNLOAD (NO NEW TAB) ==========

// Fetch the PDF first
final response = await http.get(
Uri.parse(downloadUrl),
headers: {
'Accept': 'application/pdf,application/octet-stream,*/*',
},
);

if (response.statusCode != 200) {
throw Exception('Server error: ${response.statusCode}');
}

// Convert response to Blob and trigger download
final blob = html.Blob([response.bodyBytes], 'application/pdf');
final blobUrl = html.Url.createObjectUrlFromBlob(blob);

final anchor = html.AnchorElement(href: blobUrl)
..setAttribute('download', fileName)
..style.display = 'none';

html.document.body?.append(anchor);
anchor.click();
anchor.remove();

html.Url.revokeObjectUrl(blobUrl);

if (mounted) {
Navigator.pop(context);
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Download started: $fileName'),
duration: const Duration(seconds: 2),
),
);
}

} else {
// ========== MOBILE PLATFORM ==========

final response = await http.get(
Uri.parse(downloadUrl),
headers: {
'Accept': 'application/pdf,application/octet-stream,*/*',
'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
},
);

print('Response Status: ${response.statusCode}');
print('Response Size: ${response.bodyBytes.length} bytes');

if (response.statusCode != 200) {
throw Exception('Server error: ${response.statusCode}');
}

if (response.bodyBytes.isEmpty) {
throw Exception('Downloaded file is empty');
}

// Check if response is PDF (starts with %PDF)
bool isPdf = false;
if (response.bodyBytes.length >= 4) {
isPdf = response.bodyBytes[0] == 0x25 &&
response.bodyBytes[1] == 0x50 &&
response.bodyBytes[2] == 0x44 &&
response.bodyBytes[3] == 0x46;
}

// Check if response is HTML
String responsePreview = utf8.decode(response.bodyBytes.take(100).toList());
bool isHtml = responsePreview.contains('<!DOCTYPE') ||
responsePreview.contains('<html>');

if (isHtml) {
print('⚠️ Server returned HTML, opening in browser instead');
final Uri url = Uri.parse(downloadUrl);
await launchUrl(url, mode: LaunchMode.externalApplication);

if (mounted) {
Navigator.pop(context);
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Opening invoice #$invoiceNumber in browser...'),
duration: const Duration(seconds: 2),
),
);
}
return;
}

if (!isPdf) {
throw Exception('Downloaded file is not a valid PDF');
}

// Save to app documents directory
final directory = await getApplicationDocumentsDirectory();
final filePath = '${directory.path}/$fileName';
final file = File(filePath);

if (await file.exists()) {
await file.delete();
}

await file.writeAsBytes(response.bodyBytes);

if (await file.exists()) {
final fileSize = await file.length();
print('✅ PDF Saved: $filePath (Size: $fileSize bytes)');

if (mounted) {
Navigator.pop(context);

// Show success dialog
showDialog(
context: context,
builder: (context) => AlertDialog(
title: Row(
children: [
const Icon(Icons.check_circle, color: Colors.green, size: 28),
const SizedBox(width: 10),
Text('Download Complete!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
],
),
content: Column(
mainAxisSize: MainAxisSize.min,
children: [
Text('Invoice #$invoiceNumber downloaded successfully!'),
const SizedBox(height: 16),
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.grey[100],
borderRadius: BorderRadius.circular(8),
),
child: Row(
children: [
const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
const SizedBox(width: 12),
Expanded(
child: Text(
fileName,
style: GoogleFonts.poppins(fontSize: 12),
overflow: TextOverflow.ellipsis,
),
),
],
),
),
const SizedBox(height: 8),
Text(
'Saved in App Documents',
style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
),
],
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text('Close'),
),
ElevatedButton(
onPressed: () async {
Navigator.pop(context);
await OpenFile.open(filePath);
},
style: ElevatedButton.styleFrom(
backgroundColor: Colors.blue[700],
),
child: const Text('Open PDF'),
),
],
),
);

// Toast message
Fluttertoast.showToast(
msg: 'PDF downloaded successfully!',
toastLength: Toast.LENGTH_SHORT,
gravity: ToastGravity.BOTTOM,
backgroundColor: Colors.green,
textColor: Colors.white,
);
}
} else {
throw Exception('File was not saved properly');
}
}

} catch (e) {
print('❌ Download Error: $e');
if (mounted) {
Navigator.pop(context);

// Fallback: Open in browser
final shouldOpen = await showDialog<bool>(
context: context,
builder: (context) => AlertDialog(
title: const Text('Download Failed'),
content: Text('Could not download PDF: ${e.toString()}\n\nOpen in browser instead?'),
actions: [
TextButton(
onPressed: () => Navigator.pop(context, false),
child: const Text('Cancel'),
),
ElevatedButton(
onPressed: () => Navigator.pop(context, true),
child: const Text('Open in Browser'),
),
],
),
);

if (shouldOpen == true) {
final Uri url = Uri.parse(downloadUrl);
await launchUrl(url, mode: LaunchMode.externalApplication);
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Opening invoice #$invoiceNumber in browser...'),
duration: const Duration(seconds: 2),
),
);
} else {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Error: ${e.toString()}'),
backgroundColor: Colors.red,
duration: const Duration(seconds: 3),
),
);
}
}
}
}

// ==================== INVOICE OPTIONS METHODS ====================

void _viewInvoice(Map<String, dynamic> invoice) {
showDialog(
context: context,
builder: (context) => AlertDialog(
title: Text('Invoice Details', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
content: SingleChildScrollView(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: [
_buildDetailRow('Invoice Number:', invoice['invoice']),
const SizedBox(height: 8),
_buildDetailRow('Subscription Type:', invoice['subscriptionType']),
const SizedBox(height: 8),
_buildDetailRow('Company Name:', invoice['companyName']),
const SizedBox(height: 8),
_buildDetailRow('Date:', invoice['date']),
const SizedBox(height: 8),
_buildDetailRow('Amount:', invoice['amount']),
const SizedBox(height: 8),
_buildDetailRow('Status:', invoice['status']),
const SizedBox(height: 8),
_buildDetailRow('Due Date:', invoice['dueDate']),
],
),
),
actions: [
TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
],
),
);
}

Widget _buildDetailRow(String label, String value) {
return Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
SizedBox(
width: 120,
child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[700])),
),
Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 13))),
],
);
}

void _sendInvoice(Map<String, dynamic> invoice) async {
TextEditingController emailController = TextEditingController();
TextEditingController messageController = TextEditingController();

final result = await showDialog<bool>(
context: context,
builder: (context) => AlertDialog(
title: Text('Send Invoice', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
content: Column(
mainAxisSize: MainAxisSize.min,
children: [
Text('Send invoice ${invoice['invoice']} to:', style: GoogleFonts.poppins()),
const SizedBox(height: 16),
TextField(
controller: emailController,
decoration: InputDecoration(
hintText: 'Enter email address',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
prefixIcon: const Icon(Icons.email),
),
keyboardType: TextInputType.emailAddress,
),
const SizedBox(height: 12),
TextField(
controller: messageController,
decoration: InputDecoration(
hintText: 'Optional message',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
prefixIcon: const Icon(Icons.message),
),
maxLines: 3,
),
],
),
actions: [
TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]), child: const Text('Send')),
],
),
);

if (result == true && emailController.text.isNotEmpty) {
showDialog(
context: context,
barrierDismissible: false,
builder: (context) => AlertDialog(
content: Row(
children: [
const CircularProgressIndicator(),
const SizedBox(width: 20),
Text('Sending invoice...', style: GoogleFonts.poppins()),
],
),
),
);

try {
int invoiceId = invoice['id'];
final apiUrl = 'https://demo.p2ptrack360.com:8888/api/invoices/$invoiceId/send';
Map<String, dynamic> requestBody = {'email': emailController.text.trim()};
if (messageController.text.trim().isNotEmpty) {
requestBody['message'] = messageController.text.trim();
}

final response = await http.post(
Uri.parse(apiUrl),
headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
body: json.encode(requestBody),
);

if (mounted) Navigator.pop(context);
if (response.statusCode == 200) {
final responseData = json.decode(response.body);
_showSnackBar(responseData['message'] ?? 'Invoice sent successfully!');
} else {
_showSnackBar('Failed to send invoice');
}
} catch (e) {
if (mounted) Navigator.pop(context);
_showSnackBar('Error: Could not connect to server');
}
} else if (result == true && emailController.text.isEmpty) {
_showSnackBar('Please enter an email address');
}
}

void _addPayment(Map<String, dynamic> invoice) async {
double totalAmount = invoice['amount_raw'] ?? 0;
double paidAmount = invoice['paid_amount'] ?? 0;
double remainingAmount = totalAmount - paidAmount;

TextEditingController amountController = TextEditingController();
TextEditingController paymentMethodController = TextEditingController();
TextEditingController transactionIdController = TextEditingController();
TextEditingController notesController = TextEditingController();

DateTime selectedDate = DateTime.now();
TextEditingController dateController = TextEditingController(
text: "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}"
);

List<String> paymentMethods = ['Cash', 'Bank Transfer', 'Credit Card', 'Debit Card', 'Cheque', 'Online Payment'];
String selectedPaymentMethod = 'Cash';
final formKey = GlobalKey<FormState>();

final result = await showDialog<bool>(
context: context,
builder: (context) => StatefulBuilder(
builder: (context, setState) {
return AlertDialog(
title: Text('Add Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
content: SingleChildScrollView(
child: Form(
key: formKey,
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.blue[50],
borderRadius: BorderRadius.circular(8),
border: Border.all(color: Colors.blue[200]!),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Invoice #${invoice['invoice']}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
const SizedBox(height: 8),
Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
Text('Total Amount:', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
Text('${invoice['amount']}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue[700])),
]),
const SizedBox(height: 4),
Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
Text('Paid Amount:', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
Text('\$${paidAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 13, color: Colors.green[700])),
]),
const Divider(height: 16),
Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
Text('Remaining:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
Text('\$${remainingAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: remainingAmount > 0 ? Colors.orange[700] : Colors.green[700])),
]),
],
),
),
const SizedBox(height: 16),
Text('Payment Amount *', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
const SizedBox(height: 6),
TextFormField(
controller: amountController,
decoration: InputDecoration(
hintText: 'Enter amount',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
prefixIcon: const Icon(Icons.attach_money, size: 20),
),
keyboardType: TextInputType.number,
validator: (value) {
if (value == null || value.isEmpty) return 'Please enter payment amount';
double amount = double.tryParse(value) ?? 0;
if (amount <= 0) return 'Amount must be greater than 0';
if (amount > remainingAmount) return 'Amount cannot exceed remaining amount (\$${remainingAmount.toStringAsFixed(2)})';
return null;
},
),
const SizedBox(height: 16),
Text('Payment Date *', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
const SizedBox(height: 6),
InkWell(
onTap: () async {
DateTime? pickedDate = await showDatePicker(
context: context,
initialDate: selectedDate,
firstDate: DateTime(2020),
lastDate: DateTime.now(),
);
if (pickedDate != null) {
setState(() {
selectedDate = pickedDate;
dateController.text = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
});
}
},
child: IgnorePointer(
child: TextField(
controller: dateController,
decoration: InputDecoration(
hintText: 'YYYY-MM-DD',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
prefixIcon: const Icon(Icons.calendar_today, size: 20),
),
),
),
),
const SizedBox(height: 16),
Text('Payment Method', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
const SizedBox(height: 6),
DropdownButtonFormField<String>(
value: selectedPaymentMethod,
decoration: InputDecoration(
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
prefixIcon: const Icon(Icons.payment, size: 20),
),
items: paymentMethods.map((method) => DropdownMenuItem(value: method, child: Text(method))).toList(),
onChanged: (value) {
setState(() {
selectedPaymentMethod = value ?? 'Cash';
paymentMethodController.text = selectedPaymentMethod;
});
},
),
const SizedBox(height: 16),
Text('Transaction ID', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
const SizedBox(height: 6),
TextField(
controller: transactionIdController,
decoration: InputDecoration(
hintText: 'Enter transaction ID (optional)',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
prefixIcon: const Icon(Icons.numbers, size: 20),
),
),
const SizedBox(height: 16),
Text('Notes', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
const SizedBox(height: 6),
TextField(
controller: notesController,
decoration: InputDecoration(
hintText: 'Add notes...',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
prefixIcon: const Icon(Icons.note, size: 20),
),
maxLines: 2,
),
],
),
),
),
actions: [
TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(context, true); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]), child: const Text('Add Payment')),
],
);
},
),
);

if (result == true) {
showDialog(
context: context,
barrierDismissible: false,
builder: (context) => AlertDialog(
content: Row(
children: [
const CircularProgressIndicator(),
const SizedBox(width: 20),
Text('Processing payment...', style: GoogleFonts.poppins()),
],
),
),
);

try {
int invoiceId = invoice['id'];
double amount = double.tryParse(amountController.text) ?? 0;
final apiUrl = 'https://demo.p2ptrack360.com:8888/api/invoices/$invoiceId/pay';
Map<String, dynamic> requestBody = {
'paid_amount': amount,
'payment_date': dateController.text,
};
if (paymentMethodController.text.isNotEmpty) requestBody['payment_method'] = paymentMethodController.text;
else if (selectedPaymentMethod.isNotEmpty) requestBody['payment_method'] = selectedPaymentMethod;
if (transactionIdController.text.trim().isNotEmpty) requestBody['transaction_id'] = transactionIdController.text.trim();
if (notesController.text.trim().isNotEmpty) requestBody['notes'] = notesController.text.trim();

final response = await http.post(
Uri.parse(apiUrl),
headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
body: json.encode(requestBody),
);

if (mounted) Navigator.pop(context);
if (response.statusCode == 200) {
final responseData = json.decode(response.body);
_showSnackBar(responseData['message'] ?? 'Payment recorded successfully!');
await _fetchInvoices();
} else {
_showSnackBar('Failed to record payment');
}
} catch (e) {
if (mounted) Navigator.pop(context);
_showSnackBar('Error: Could not connect to server');
}
}
}

void _cancelInvoice(Map<String, dynamic> invoice) async {
TextEditingController reasonController = TextEditingController();
final result = await showDialog<bool>(
context: context,
builder: (context) => AlertDialog(
title: Row(
children: [
const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
const SizedBox(width: 8),
Text('Cancel Invoice?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red)),
],
),
content: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Are you sure you want to cancel this invoice?', style: GoogleFonts.poppins(fontSize: 14)),
const SizedBox(height: 12),
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange[200]!)),
child: Row(
children: [
Icon(Icons.warning, color: Colors.orange[700], size: 20),
const SizedBox(width: 8),
Expanded(child: Text('⚠️ This action cannot be undone. The invoice status will be changed to "cancelled".', style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange[800]))),
],
),
),
const SizedBox(height: 16),
Text('Reason for cancellation', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
const SizedBox(height: 8),
TextField(
controller: reasonController,
decoration: InputDecoration(
hintText: 'Enter reason (optional)',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
),
maxLines: 2,
),
],
),
actions: [
TextButton(onPressed: () => Navigator.pop(context, false), style: TextButton.styleFrom(foregroundColor: Colors.grey[600]), child: const Text('No, keep it')),
ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Yes, cancel it!')),
],
),
);

if (result == true) {
showDialog(
context: context,
barrierDismissible: false,
builder: (context) => AlertDialog(
content: Row(
children: [
const CircularProgressIndicator(),
const SizedBox(width: 20),
Text('Cancelling invoice...', style: GoogleFonts.poppins()),
],
),
),
);

try {
int invoiceId = invoice['id'];
final apiUrl = 'https://demo.p2ptrack360.com:8888/api/invoices/$invoiceId/cancel';
Map<String, dynamic> requestBody = {};
if (reasonController.text.trim().isNotEmpty) requestBody['reason'] = reasonController.text.trim();

final response = await http.post(
Uri.parse(apiUrl),
headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
body: json.encode(requestBody),
);

if (mounted) Navigator.pop(context);
if (response.statusCode == 200) {
final responseData = json.decode(response.body);
_showSnackBar(responseData['message'] ?? 'Invoice cancelled successfully!');
await _fetchInvoices();
} else {
_showSnackBar('Failed to cancel invoice');
}
} catch (e) {
if (mounted) Navigator.pop(context);
_showSnackBar('Error: Could not connect to server');
}
}
}

void _sendPaymentReminder(Map<String, dynamic> invoice) async {
TextEditingController emailController = TextEditingController();
TextEditingController subjectController = TextEditingController();
TextEditingController messageController = TextEditingController();

String formattedDueDate = invoice['dueDate'];
String amount = invoice['amount'].replaceAll('\$', '');
String invoiceNumber = invoice['invoice'];
String companyName = invoice['companyName'];

subjectController.text = '🔔 Reminder: Invoice #$invoiceNumber is due on $formattedDueDate';
messageController.text = 'Dear $companyName,\n\nThis is a friendly reminder that invoice #$invoiceNumber for \$$amount is due on $formattedDueDate.\n\nPlease process the payment at your earliest convenience.\n\nThank you for your business!\n\nBest regards,\n${_companyData?['name'] ?? 'Company'} Team';

bool includePaymentLink = false;
bool sendMeCopy = false;

final result = await showDialog<bool>(
context: context,
builder: (context) => StatefulBuilder(
builder: (context, setState) {
return AlertDialog(
title: Text('Send Payment Reminder', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue[200]!)),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Invoice #$invoiceNumber', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
const SizedBox(height: 4),
Text('Amount: ${invoice['amount']}', style: GoogleFonts.poppins(fontSize: 12)),
Text('Due Date: $formattedDueDate', style: GoogleFonts.poppins(fontSize: 12)),
],
),
),
const SizedBox(height: 16),
Text('Email Address *', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
const SizedBox(height: 6),
TextField(
controller: emailController,
decoration: InputDecoration(
hintText: 'tech@gmail.com',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
prefixIcon: const Icon(Icons.email, size: 20),
),
keyboardType: TextInputType.emailAddress,
),
const SizedBox(height: 16),
Text('Subject', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
const SizedBox(height: 6),
TextField(
controller: subjectController,
decoration: InputDecoration(
hintText: 'Reminder: Invoice is due soon',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
prefixIcon: const Icon(Icons.subject, size: 20),
),
),
const SizedBox(height: 16),
Text('Message', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
const SizedBox(height: 6),
TextField(
controller: messageController,
decoration: InputDecoration(
hintText: 'Enter your message here...',
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
alignLabelWithHint: true,
),
maxLines: 6,
),
const SizedBox(height: 16),
CheckboxListTile(
value: includePaymentLink,
onChanged: (value) => setState(() => includePaymentLink = value ?? false),
title: Text('Include payment link', style: GoogleFonts.poppins(fontSize: 13)),
controlAffinity: ListTileControlAffinity.leading,
dense: true,
contentPadding: EdgeInsets.zero,
),
CheckboxListTile(
value: sendMeCopy,
onChanged: (value) => setState(() => sendMeCopy = value ?? false),
title: Text('Send me a copy', style: GoogleFonts.poppins(fontSize: 13)),
controlAffinity: ListTileControlAffinity.leading,
dense: true,
contentPadding: EdgeInsets.zero,
),
],
),
),
actions: [
TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
ElevatedButton(
onPressed: () {
if (emailController.text.trim().isEmpty) {
_showSnackBar('Please enter an email address');
return;
}
Navigator.pop(context, true);
},
style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
child: const Text('Send Reminder'),
),
],
);
},
),
);

if (result == true && emailController.text.isNotEmpty) {
showDialog(
context: context,
barrierDismissible: false,
builder: (context) => AlertDialog(
content: Row(
children: [
const CircularProgressIndicator(),
const SizedBox(width: 20),
Text('Sending reminder...', style: GoogleFonts.poppins()),
],
),
),
);

try {
int invoiceId = invoice['id'];
final apiUrl = 'https://demo.p2ptrack360.com:8888/api/invoices/$invoiceId/reminder';
Map<String, dynamic> requestBody = {
'email': emailController.text.trim(),
'subject': subjectController.text.trim(),
'message': messageController.text.trim(),
'send_copy': sendMeCopy ? 1 : 0,
};

final response = await http.post(
Uri.parse(apiUrl),
headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
body: json.encode(requestBody),
);

if (mounted) Navigator.pop(context);
if (response.statusCode == 200) {
final responseData = json.decode(response.body);
_showSnackBar(responseData['message'] ?? 'Payment reminder sent successfully!');
} else {
_showSnackBar('Failed to send reminder');
}
} catch (e) {
if (mounted) Navigator.pop(context);
_showSnackBar('Error: Could not connect to server');
}
}
}

void _showInvoiceOptions(Map<String, dynamic> invoice) {
showModalBottomSheet(
context: context,
isScrollControlled: true,
shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
builder: (context) {
return SafeArea(
child: DraggableScrollableSheet(
initialChildSize: 0.5,
minChildSize: 0.3,
maxChildSize: 0.7,
expand: false,
builder: (context, scrollController) {
return SingleChildScrollView(
controller: scrollController,
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const SizedBox(height: 8),
Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
const SizedBox(height: 16),
Text('Invoice Options', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
const SizedBox(height: 8),
Divider(color: Colors.grey[300]),
_buildOptionTile(icon: Icons.visibility, title: 'View', color: Colors.blue, onTap: () { Navigator.pop(context); _viewInvoice(invoice); }),
_buildOptionTile(icon: Icons.download, title: 'Download', color: Colors.green, onTap: () { Navigator.pop(context); _downloadInvoice(invoice); }),
_buildOptionTile(icon: Icons.send, title: 'Send', color: Colors.purple, onTap: () { Navigator.pop(context); _sendInvoice(invoice); }),
_buildOptionTile(icon: Icons.payment, title: 'Add Payment', color: Colors.teal, onTap: () { Navigator.pop(context); _addPayment(invoice); }),
_buildOptionTile(icon: Icons.cancel, title: 'Cancel', color: Colors.red, onTap: () { Navigator.pop(context); _cancelInvoice(invoice); }),
_buildOptionTile(icon: Icons.notification_important, title: 'Payment Reminder', color: Colors.amber, onTap: () { Navigator.pop(context); _sendPaymentReminder(invoice); }),
const SizedBox(height: 16),
],
),
);
},
),
);
},
);
}

Widget _buildOptionTile({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
return ListTile(
leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 24)),
title: Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
onTap: onTap,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);
}

void _showSnackBar(String message) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3), behavior: SnackBarBehavior.floating));
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.grey[50],
appBar: AppBar(
title: const Text('Company Profile'),
backgroundColor: const Color(0xff332757),
foregroundColor: Colors.white,
centerTitle: true,
actions: [
IconButton(icon: const Icon(Icons.refresh), onPressed: () { _fetchCompanyProfile(); _fetchSubscriptionPackages(); _fetchInvoices(); }, tooltip: 'Refresh'),
],
),
body: _isLoading
? const Center(child: CircularProgressIndicator())
    : _hasError
? Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const Icon(Icons.error, size: 64, color: Colors.red),
const SizedBox(height: 16),
Text('Failed to load company profile', style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[700])),
const SizedBox(height: 16),
ElevatedButton(onPressed: () { _fetchCompanyProfile(); _fetchSubscriptionPackages(); }, child: const Text('Retry')),
],
),
)
    : SingleChildScrollView(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Header Section
Container(
color: Colors.white,
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
width: 65,
height: 65,
decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue[50], border: Border.all(color: Colors.blue[200]!, width: 2)),
child: _companyData?['profile'] != null
? ClipRRect(
borderRadius: BorderRadius.circular(32.5),
child: Image.network('https://demo.p2ptrack360.com:8888/${_companyData!['profile']}', fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Icon(Icons.business, size: 40, color: Colors.blue)),
)
    : Icon(Icons.business, size: 40, color: Colors.blue),
),
const SizedBox(width: 15),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Expanded(child: Text(_companyData?['name'] ?? 'Tech Solutions Inc', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800]), maxLines: 2, overflow: TextOverflow.ellipsis)),
Container(
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
decoration: BoxDecoration(color: (_companyData?['active'] == 1 ? Colors.green[50] : Colors.red[50]), borderRadius: BorderRadius.circular(12), border: Border.all(color: _companyData?['active'] == 1 ? Colors.green : Colors.red)),
child: Text(_companyData?['active'] == 1 ? 'Active' : 'Inactive', style: GoogleFonts.poppins(color: _companyData?['active'] == 1 ? Colors.green[700] : Colors.red[700], fontWeight: FontWeight.bold, fontSize: 12)),
),
],
),
const SizedBox(height: 6),
Text(_companyData?['domain_title'] ?? 'IT Services', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
const SizedBox(height: 8),
Row(
children: [
Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
const SizedBox(width: 6),
Expanded(child: Text(_getCompanyAddress(), style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)),
],
),
const SizedBox(height: 4),
Row(
children: [
Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
const SizedBox(width: 6),
Text('Member since ${_getEstablishedDate().split(', ').last}', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14)),
],
),
],
),
),
],
),
const SizedBox(height: 20),
Row(
children: [
Expanded(
child: ElevatedButton.icon(
onPressed: () {},
icon: const Icon(Icons.email, size: 16),
label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Message')),
style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
),
),
const SizedBox(width: 8),
Expanded(
child: ElevatedButton.icon(
onPressed: () {},
icon: const Icon(Icons.phone, size: 16),
label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Call')),
style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
),
),
const SizedBox(width: 8),
Expanded(
child: OutlinedButton.icon(
onPressed: () {},
icon: const Icon(Icons.print, size: 16),
label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Print')),
style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), side: BorderSide(color: Colors.grey[400]!)),
),
),
],
),
],
),
),
// Main Content
Padding(
padding: const EdgeInsets.all(15),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Top 4 Cards
GridView.builder(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
crossAxisSpacing: 16,
mainAxisSpacing: 16,
childAspectRatio: 1.2,
),
itemCount: _topCards.length,
itemBuilder: (context, index) {
final card = _topCards[index];
return Container(
decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisAlignment: MainAxisAlignment.center,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: card['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(card['icon'] as IconData, color: card['color'] as Color, size: 20)),
Text(card['change'], style: GoogleFonts.poppins(color: card['changeColor'] as Color, fontWeight: FontWeight.bold, fontSize: 12)),
],
),
const SizedBox(height: 12),
Text(card['title'], style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
const SizedBox(height: 4),
Text(card['value'].toString(), style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800])),
],
),
),
);
},
),
const SizedBox(height: 15),
// Company Overview Card
Card(
elevation: 4,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
child: Padding(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Company Overview', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
const SizedBox(height: 15),
_buildInfoCardRow('REGISTRATION NUMBER', _companyData?['registration_number'] ?? 'REG1234578'),
const SizedBox(height: 10),
_buildInfoCardRow('CONTACT PERSON', _getContactPerson()),
const SizedBox(height: 10),
_buildInfoCardRow('ESTABLISHED', _getEstablishedDate()),
const SizedBox(height: 10),
_buildInfoCardRow('WEBSITE', _companyData?['website'] ?? 'www.techsolution.com'),
],
),
),
),
const SizedBox(height: 15),
// Contact Information Card
Card(
elevation: 3,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
child: Padding(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Contact Information', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
const SizedBox(height: 20),
_buildContactInfoRow(Icons.email, 'Primary Email', _companyData?['email'] ?? 'tech@gmail.com'),
const SizedBox(height: 16),
_buildContactInfoRow(Icons.phone, 'Phone Number', _companyData?['telephon'] ?? '1234567890'),
const SizedBox(height: 16),
_buildContactInfoRow(Icons.support_agent, 'Support Email', _companyData?['support_email'] ?? 'support@techsolution.com'),
const SizedBox(height: 16),
_buildContactInfoRow(Icons.contact_phone, 'Support Contact', _companyData?['support_contact'] ?? '1234567891'),
const SizedBox(height: 20),
Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(Icons.location_on, color: Colors.blue[700], size: 20),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Company Address', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700])),
const SizedBox(height: 4),
Text(_getCompanyAddress(), style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
],
),
),
],
),
),
],
),
),
),
const SizedBox(height: 15),
// Current Plan Card
Card(
elevation: 3,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
child: Padding(
padding: const EdgeInsets.all(15),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text('Current Plan', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
if (_isLoadingPackages) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
],
),
const SizedBox(height: 20),
if (_currentPlan != null) _buildPlanCard(),
if (_currentPlan == null && !_isLoadingPackages)
Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
child: Center(child: Text('No subscription plan found', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]))),
),
],
),
),
),
const SizedBox(height: 15),
// Recent Activity Card
Card(
elevation: 3,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
child: Padding(
padding: const EdgeInsets.all(15),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(children: [Icon(Icons.access_time_rounded), const SizedBox(width: 5), Text('Recent Activity', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]))]),
const SizedBox(height: 20),
Column(
children: activities.asMap().entries.map((entry) {
final index = entry.key;
final activity = entry.value;
final isLast = index == activities.length - 1;
return Padding(
padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Column(
children: [
Container(width: 24, height: 24, decoration: BoxDecoration(color: activity['color'] as Color, borderRadius: BorderRadius.circular(12)), child: Icon(activity['icon'] as IconData, size: 14, color: Colors.white)),
if (!isLast) Container(width: 2, height: 40, color: Colors.grey[300], margin: const EdgeInsets.only(top: 4)),
],
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(activity['time'], style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
const SizedBox(height: 4),
Text(activity['action'], style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87)),
],
),
),
],
),
);
}).toList(),
),
],
),
),
),
const SizedBox(height: 15),
// Location Card
if (_companyLocation != null)
Card(
elevation: 3,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
child: Padding(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Location', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
const SizedBox(height: 16),
Container(
height: 250,
decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all()),
child: ClipRRect(
borderRadius: BorderRadius.circular(8),
child: GoogleMap(
initialCameraPosition: CameraPosition(target: _companyLocation!, zoom: 12),
markers: _markers,
zoomControlsEnabled: true,
mapToolbarEnabled: true,
myLocationEnabled: true,
myLocationButtonEnabled: true,
onMapCreated: (controller) { setState(() { _mapController = controller; }); },
),
),
),
],
),
),
),
const SizedBox(height: 15),
// Recent Invoices Card
Card(
elevation: 3,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
child: Padding(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text('Recent Invoices', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
TextButton(onPressed: () { _fetchInvoices(); }, style: TextButton.styleFrom(foregroundColor: Colors.blue[700]), child: const Row(children: [Text('Refresh'), SizedBox(width: 4), Icon(Icons.refresh, size: 16)])),
],
),
const SizedBox(height: 20),
if (_isLoadingInvoices)
const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
else if (_invoiceErrorMessage != null)
Center(
child: Padding(
padding: const EdgeInsets.all(20),
child: Column(
children: [
Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
const SizedBox(height: 12),
Text(_invoiceErrorMessage!, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
const SizedBox(height: 12),
ElevatedButton(onPressed: _fetchInvoices, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]), child: const Text('Retry')),
],
),
),
)
else if (invoices.isEmpty)
Center(
child: Padding(
padding: const EdgeInsets.all(20),
child: Column(children: [Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]), const SizedBox(height: 12), Text('No invoices found', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]))]),
),
)
else
SingleChildScrollView(
scrollDirection: Axis.horizontal,
physics: const BouncingScrollPhysics(),
child: Container(
decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all()),
child: DataTable(
headingRowHeight: 50,
dataRowHeight: 60,
columnSpacing: 20,
horizontalMargin: 12,
columns: const [
DataColumn(label: SizedBox(width: 120, child: Text('INVOICE', style: TextStyle(fontWeight: FontWeight.bold)))),
DataColumn(label: SizedBox(width: 140, child: Text('SUBSCRIPTION TYPE', style: TextStyle(fontWeight: FontWeight.bold)))),
DataColumn(label: SizedBox(width: 140, child: Text('COMPANY NAME', style: TextStyle(fontWeight: FontWeight.bold)))),
DataColumn(label: SizedBox(width: 100, child: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold)))),
DataColumn(label: SizedBox(width: 100, child: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.bold)))),
DataColumn(label: SizedBox(width: 100, child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold)))),
DataColumn(label: SizedBox(width: 100, child: Text('DUE DATE', style: TextStyle(fontWeight: FontWeight.bold)))),
DataColumn(label: SizedBox(width: 80, child: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold)))),
],
rows: invoices.map((invoice) {
return DataRow(
cells: [
DataCell(SizedBox(width: 120, child: Text(invoice['invoice'], style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12)))),
DataCell(SizedBox(width: 140, child: Text(invoice['subscriptionType'], style: GoogleFonts.poppins(fontSize: 12), overflow: TextOverflow.ellipsis))),
DataCell(SizedBox(width: 140, child: Text(invoice['companyName'], style: GoogleFonts.poppins(fontSize: 12), overflow: TextOverflow.ellipsis))),
DataCell(SizedBox(width: 100, child: Text(invoice['date'], style: const TextStyle(fontSize: 12)))),
DataCell(SizedBox(width: 100, child: Text(invoice['amount'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)))),
DataCell(SizedBox(
width: 100,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
decoration: BoxDecoration(color: (invoice['statusColor'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: invoice['statusColor'] as Color, width: 1)),
child: Text(invoice['status'], style: GoogleFonts.poppins(color: invoice['statusColor'] as Color, fontWeight: FontWeight.bold, fontSize: 11)),
),
)),
DataCell(SizedBox(width: 100, child: Text(invoice['dueDate'], style: const TextStyle(fontSize: 12)))),
DataCell(SizedBox(width: 80, child: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showInvoiceOptions(invoice), tooltip: 'Options'))),
],
);
}).toList(),
),
),
),
const SizedBox(height: 10),
if (invoices.isNotEmpty && MediaQuery.of(context).size.width < 900)
Padding(
padding: const EdgeInsets.only(top: 8),
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey[400]),
Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
const SizedBox(width: 4),
Text('Scroll horizontally to see all columns', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
],
),
),
],
),
),
),
const SizedBox(height: 20),
],
),
),
],
),
),
);
}

Widget _buildPlanCard() {
return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue[200]!)),
child: Column(
mainAxisAlignment: MainAxisAlignment.start,
children: [
Text(_currentPlan!['title'] ?? 'Basic Plan', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[800])),
const SizedBox(height: 4),
Text(_currentPlan!['description'] ?? 'Standard subscription package', style: GoogleFonts.poppins(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
const SizedBox(height: 16),
Column(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
_buildPlanDetailWithIcon(Icons.people, '${_currentPlan!['no_of_licence'] ?? '1'} Users'),
const SizedBox(height: 10),
_buildPlanDetailWithIcon(Icons.storage, 'Unlimited Storage'),
const SizedBox(height: 10),
_buildPlanDetailWithIcon(Icons.support_agent, '24/7 Support'),
const SizedBox(height: 10),
_buildPlanDetailWithIcon(Icons.api, 'API Access'),
],
),
const SizedBox(height: 20),
const Divider(height: 1, color: Colors.grey),
const SizedBox(height: 16),
SingleChildScrollView(
scrollDirection: Axis.horizontal,
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Container(
width: 140,
padding: const EdgeInsets.only(right: 8),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Monthly Cost', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
const SizedBox(height: 4),
Text('\$${_currentPlan!['price'] ?? '19.99'}/month', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
],
),
),
Container(
width: 140,
padding: const EdgeInsets.only(left: 8),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Renewal Date', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
const SizedBox(height: 4),
Text(_getRenewalDate(), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
],
),
),
],
),
),
const SizedBox(height: 16),
SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: () { _showUpgradeDialog(); },
style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
child: const Text('Upgrade Plan'),
),
),
],
),
);
}

void _showUpgradeDialog() {
showDialog(
context: context,
builder: (context) => Dialog(
insetPadding: const EdgeInsets.all(20),
child: Container(
constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9, maxHeight: MediaQuery.of(context).size.height * 0.8),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Padding(padding: const EdgeInsets.all(20), child: Text('Upgrade Plan', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold))),
Expanded(
child: SingleChildScrollView(
padding: const EdgeInsets.symmetric(horizontal: 20),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Text('Choose a new plan to upgrade your subscription', style: GoogleFonts.poppins(color: Colors.grey[600]), textAlign: TextAlign.center),
const SizedBox(height: 20),
..._subscriptionPackages.where((plan) => _currentPlan == null || plan['id'] != _currentPlan!['id']).map((plan) {
return Container(
margin: const EdgeInsets.only(bottom: 12),
decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
child: ListTile(
title: Text(plan['title']?.toString() ?? 'Plan', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey[800], fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
subtitle: Padding(
padding: const EdgeInsets.only(top: 4),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(plan['description']?.toString() ?? 'Subscription package', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
const SizedBox(height: 8),
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Flexible(child: Text('\$${plan['price']?.toString() ?? '0'}/month', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green[700]), maxLines: 1, overflow: TextOverflow.ellipsis)),
const SizedBox(width: 8),
Flexible(child: Text('${plan['no_of_licence']?.toString() ?? '1'} license${plan['no_of_licence']?.toString() == '1' ? '' : 's'}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis)),
],
),
],
),
),
trailing: ConstrainedBox(
constraints: const BoxConstraints(maxWidth: 80, minWidth: 70),
child: ElevatedButton(
onPressed: () { Navigator.pop(context); _showUpgradeConfirmation(plan); },
style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: const Size(70, 36)),
child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Upgrade', style: TextStyle(fontSize: 12))),
),
),
),
);
}).toList(),
],
),
),
),
Padding(padding: const EdgeInsets.all(20), child: SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')))),
],
),
),
),
);
}

void _showUpgradeConfirmation(Map<String, dynamic> newPlan) {
showDialog(
context: context,
builder: (context) => AlertDialog(
title: Text('Confirm Upgrade', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
content: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Are you sure you want to upgrade to ${newPlan['title']}?', style: GoogleFonts.poppins()),
const SizedBox(height: 16),
Text('New price: \$${newPlan['price']}/month', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green[700])),
Text('Licenses: ${newPlan['no_of_licence']}', style: GoogleFonts.poppins(color: Colors.grey[600])),
],
),
actions: [
TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
ElevatedButton(onPressed: () async { Navigator.pop(context); await _performUpgrade(newPlan); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white), child: const Text('Confirm Upgrade')),
],
),
);
}

Future<void> _performUpgrade(Map<String, dynamic> newPlan) async {
showDialog(
context: context,
barrierDismissible: false,
builder: (context) => AlertDialog(
content: Row(children: [const CircularProgressIndicator(), const SizedBox(width: 20), Flexible(child: Text('Upgrading to ${newPlan['title']}...', style: GoogleFonts.poppins()))]),
),
);
try {
await _storeUpgradedPlanId(newPlan['id']);
_updateCurrentPlan(newPlan);
await Future.delayed(const Duration(seconds: 1));
if (mounted) { Navigator.pop(context); _showSnackBar('Successfully upgraded to ${newPlan['title']}!'); }
} catch (e) {
if (mounted) { Navigator.pop(context); _showSnackBar('Upgrade failed: ${e.toString()}'); }
}
}

Widget _buildContactInfoRow(IconData icon, String label, String value) {
return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
child: Row(
children: [
Icon(icon, color: Colors.blue[700], size: 20),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(label, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
const SizedBox(height: 4),
Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)),
],
),
),
],
),
);
}

Widget _buildPlanDetailWithIcon(IconData icon, String text) {
return Row(
children: [
Icon(icon, color: Colors.blue[700], size: 24),
const SizedBox(width: 15),
Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))),
],
);
}

Widget _buildInfoCardRow(String label, String value) {
return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Flexible(child: Text(label, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]))),
Flexible(child: Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis, maxLines: 1)),
],
),
);
}
}
