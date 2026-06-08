import 'package:flutter/material.dart';
import 'package:anwar/constant.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Chats extends StatefulWidget {
  const Chats({super.key});

  @override
  State<Chats> createState() => _ChatsState();
}

class _ChatsState extends State<Chats> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email') ?? '';
    final password = prefs.getString('two_factor_secret') ?? '';
    // final two_factor_secret = prefs.getString('two_factor_secret') ?? '';

    // URL login (if server supports query params)
    final chatUrl =
        'https://demo.p2ptrack360.com:8080/chat/public/conversations'
        '?email=$email&password=$password';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            // Inject JS to auto-fill login form (in case URL login doesn't work)
            try {
              await _controller?.runJavaScript('''
                if(document.getElementById('email')){
                  document.getElementById('email').value = '$email';
                  document.getElementById('password').value = '$password';
                  document.getElementById('loginButton')?.click();
                }
              ''');
            } catch (e) {
              print("JS injection failed: $e");
            }

            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(chatUrl));

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: MyDrawer(),
      appBar: AppBar(
        title: Text(
          'Chats',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: const Color(0xff332757),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_controller != null)
              WebViewWidget(controller: _controller!),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}















// import 'package:flutter/material.dart';
// import 'package:anwar/constant.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:webview_flutter/webview_flutter.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class Chats extends StatefulWidget {
//   final bool skipLogin; // true if coming from other screen
//
//   const Chats({super.key, this.skipLogin = false});
//
//   @override
//   State<Chats> createState() => _ChatsState();
// }
//
//
// class _ChatsState extends State<Chats> {
//   late final WebViewController _controller;
//   bool _isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onPageStarted: (String url) {
//             setState(() {
//               _isLoading = true;
//             });
//           },
//           onPageFinished: (String url) {
//             setState(() {
//               _isLoading = false;
//             });
//           },
//         ),
//       );
//
//     _loadUrlWithCookies();
//   }
//
//   Future<void> _loadUrlWithCookies() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//
//       if (!widget.skipLogin) {
//         final token = prefs.getString('auth_token');
//         final sessionId = prefs.getString('session_id');
//
//         final cookieManager = WebViewCookieManager();
//         await cookieManager.clearCookies();
//
//         if (token != null && token.isNotEmpty) {
//           await cookieManager.setCookie(
//             WebViewCookie(
//               name: 'auth_token',
//               value: token,
//               domain: 'demo.p2ptrack360.com',
//               path: '/',
//             ),
//           );
//         }
//
//         if (sessionId != null && sessionId.isNotEmpty) {
//           await cookieManager.setCookie(
//             WebViewCookie(
//               name: 'session_id',
//               value: sessionId,
//               domain: 'demo.p2ptrack360.com',
//               path: '/',
//             ),
//           );
//           await cookieManager.setCookie(
//             WebViewCookie(
//               name: 'laravel_session',
//               value: sessionId,
//               domain: 'demo.p2ptrack360.com',
//               path: '/',
//             ),
//           );
//         }
//
//         // small delay to ensure cookies are set
//         await Future.delayed(const Duration(milliseconds: 300));
//       }
//
//       // Load the chat screen directly
//       await _controller.loadRequest(
//         Uri.parse('https://demo.p2ptrack360.com:8080/chat/public/conversations'),
//       );
//     } catch (e) {
//       print("Error loading WebView: $e");
//     }
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       drawer: MyDrawer(),
//       appBar: AppBar(
//         title:  Text('Chats', style: GoogleFonts.poppins(color:Colors.white),),
//         backgroundColor: Color(0xff332757),
//         iconTheme: const IconThemeData(color: Colors.white),
//       ),
//       body: SafeArea(
//         child: Stack(
//           children: [
//             WebViewWidget(controller: _controller),
//             if (_isLoading)
//               Center(
//                 child: CircularProgressIndicator(),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
