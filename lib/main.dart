import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
imd_preferences/shared_preferences.dart';
import 'package:anwarport 'package:http/http.dart' as http;
import 'package:share/dashboard.dart';


void main() {
  runApp( MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
/// -------------------- Splash Screen --------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 5), () async {
      final prefs = await SharedPreferences.getInstance();
      final IsLogin = prefs.getString("islogin");
      print(IsLogin);
      if (IsLogin == "true") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Dashboard()),
        );
        print('splash screen');
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    },);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double logoSize = size.width * 0.4;

    return Scaffold(
      backgroundColor: const Color(0xff332757),
      body: Center(
        child: Image.asset(
          "assets/logo.png",
          width: logoSize,
          height: logoSize,
          color: Colors.white,
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (context, error, stackTrace) {
            return  Text(
              'Image not found',
              style: GoogleFonts.poppins(color: Colors.white),
            );
          },
        ),
      ),
    );
  }
}

/// -------------------- Login Screen --------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();


  bool rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Please enter both email and password");
      return;
    }

    setState(() => _isLoading = true);

    const String url = "http://3.137.76.254/Service-Manager-main-Work/public/api/login";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      print("Status: ${response.statusCode}");
      print("Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if login was successful based on your API response structure
        if (data["email"] != null) {
          final prefs = await SharedPreferences.getInstance();

          // Handle null values by providing default values or checking existence
          await prefs.setString("id", data["id"]?.toString() ?? "");
          await prefs.setString("email", data["email"] ?? "");
          await prefs.setString("name", data["name"] ?? "");
          await prefs.setString("password", data["password"] ?? "");
          await prefs.setString("company", data["company_id"]?.toString() ?? "");
          await prefs.setString("phone", data["phone"]?.toString() ?? "");
          await prefs.setString("is_super_admin", data["is_super_admin"]?.toString() ?? "");
          await prefs.setString("address", data["address"] ?? "");
          await prefs.setString("islogin", "true");


          _showSnackBar("Login successful!");

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Dashboard()),
          );
        } else {
          _showSnackBar("Invalid credentials, please try again");
        }
      } else {
        _showSnackBar("Login failed: ${response.statusCode}");
      }
    } catch (e) {
      _showSnackBar("Error: $e");
      print("Detailed error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double width = size.width;
    final double height = size.height;

    return Scaffold(
      backgroundColor: const Color(0xff332757),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [

              Container(
                height: height * 0.45,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xff332757),
                      Color(0xff483a7a),
                      Color(0xff241b3f),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(60),
                    bottomRight: Radius.circular(60),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      "assets/logo.png",
                      width: width * 0.25,
                      height: width * 0.25,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),


                    Text(
                      "Welcome To",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: width * 0.075,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      "P2P Track 360",
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: width * 0.06,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  ],
                ),
              ),


              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.07,
                  vertical: height * 0.06,
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.06,
                    vertical: height * 0.03,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 25,
                        spreadRadius: 2,
                        offset: const Offset(-10, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline,
                              color: Color(0xff332757)),
                          labelText: "Email",
                          hintText: "Enter your email",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      SizedBox(height: height * 0.02),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: Color(0xff332757)),
                          labelText: "Password",
                          hintText: "Enter password",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xff332757),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: height * 0.015),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                activeColor: const Color(0xff332757),
                                value: rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    rememberMe = value!;
                                  });
                                },
                              ),
                              const Text("Remember Me"),
                            ],
                          ),
                          TextButton(
                            onPressed: () {},
                            child:  Text(
                              "Forgot Password?",
                              style: GoogleFonts.poppins(
                                color: Color(0xff332757),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: height * 0.025),


                      _isLoading
                          ? const CircularProgressIndicator(
                          color: Color(0xff332757))
                          : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff332757),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: _login,
                        child:  Text(
                          "Login",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}























// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:plogin/dashboard.dart';
// import 'package:plogin/constant.dart';
//
// void main() {
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: SplashScreen(),
//     );
//   }
// }
//
// /// -------------------- Splash Screen --------------------
// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});
//
//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }
//
// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();
//     Timer(const Duration(seconds: 3), () {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const LoginScreen()),
//       );
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final double logoSize = size.width * 0.4;
//
//     return Scaffold(
//       backgroundColor: const Color(0xff332757),
//       body: Center(
//         child: Image.asset(
//           "assets/logo.png",
//           width: logoSize,
//           height: logoSize,
//           color: Colors.white,
//           colorBlendMode: BlendMode.srcIn,
//           errorBuilder: (context, error, stackTrace) {
//             return const Text(
//               'Image not found',
//               style: TextStyle(color: Colors.white),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
//
// /// -------------------- Login Screen --------------------
// /// -------------------- Login Screen --------------------
// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});
//
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen> {
//   bool rememberMe = false;
//   bool _obscurePassword = true;
//
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final double width = size.width;
//     final double height = size.height;
//
//     // Responsive scaling factors
//     final double horizontalPadding = width * 0.07;
//     final double fieldSpacing = height * 0.02;
//     final double logoSize = width * 0.25;
//     final double topSectionHeight = height * 0.45;
//
//     return Scaffold(
//       backgroundColor: const Color(0xff332757), // Updated background color
//       body: SafeArea(
//         child: SingleChildScrollView(
//           physics: const BouncingScrollPhysics(),
//           child: Column(
//             children: [
//               // --------- Top Section (Logo + Welcome Text) ----------
//               Container(
//                 height: topSectionHeight,
//                 width: double.infinity,
//                 decoration: const BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [
//                       Color(0xff332757), // base
//                       Color(0xff483a7a), // lighter tone
//                       Color(0xff241b3f), // darker tone
//                     ]
//
//
//                     ,
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                   ),
//                   borderRadius: BorderRadius.only(
//                     bottomLeft: Radius.circular(60),
//                     bottomRight: Radius.circular(60),
//                   ),
//                 ),
//                 child: LayoutBuilder(
//                   builder: (context, constraints) {
//                     final localHeight = constraints.maxHeight;
//                     return Stack(
//                       alignment: Alignment.center,
//                       children: [
//                         Positioned(
//                           top: localHeight * 0.15,
//                           child: Image.asset(
//                             "assets/logo.png",
//                             width: logoSize,
//                             height: logoSize,
//                             color: Colors.white,
//                             colorBlendMode: BlendMode.srcIn,
//                             errorBuilder: (context, error, stackTrace) {
//                               return const Text(
//                                 'Logo not found',
//                                 style: TextStyle(color: Colors.white),
//                               );
//                             },
//                           ),
//                         ),
//                         Positioned(
//                           bottom: localHeight * 0.35,
//                           child: Text(
//                             "P2P Track 360",
//                             style: TextStyle(
//                               color: Colors.white.withOpacity(0.95),
//                               fontSize: width * 0.06,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         Positioned(
//                           bottom: localHeight * 0.1,
//
//                           child: Text(
//                             "Welcome Back",
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: width * 0.075,
//                               fontWeight: FontWeight.bold,
//                               shadows: [
//                                 Shadow(
//                                   color: Colors.black.withOpacity(0.3),
//                                   offset: const Offset(1, 2),
//                                   blurRadius: 4,
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     );
//                   },
//                 ),
//               ),
//
//               // --------- Login Form Section ----------
//               Padding(
//                 padding: EdgeInsets.symmetric(
//                   horizontal: horizontalPadding,
//                   vertical: height * 0.06,
//                 ),
//                 child: Container(
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.95),
//                     borderRadius: BorderRadius.circular(30),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.25),
//                         blurRadius: 25,
//                         spreadRadius: 2,
//                         offset: const Offset(-10, 10),
//                       ),
//                     ],
//                   ),
//                   padding: EdgeInsets.symmetric(
//                     horizontal: width * 0.06,
//                     vertical: height * 0.03,
//                   ),
//                   child: Column(
//                     children: [
//                       TextField(
//                         decoration: InputDecoration(
//                           prefixIcon:
//                           const Icon(Icons.person_outline, color:Color(0xff332757) ),
//                           labelText: "Username",
//                           hintText: "Enter User ID or Email",
//                           filled: true,
//                           fillColor: Colors.grey.shade100,
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(15),
//                             borderSide: BorderSide.none,
//                           ),
//                         ),
//                       ),
//                       SizedBox(height: fieldSpacing),
//                       TextField(
//                         obscureText: _obscurePassword,
//                         decoration: InputDecoration(
//                           prefixIcon:
//                           const Icon(Icons.lock_outline, color: Color(0xff332757)),
//                           labelText: "Password",
//                           hintText: "Enter Password",
//                           filled: true,
//                           fillColor: Colors.grey.shade100,
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(15),
//                             borderSide: BorderSide.none,
//                           ),
//                           suffixIcon: IconButton(
//                             icon: Icon(
//                               _obscurePassword
//                                   ? Icons.visibility_off
//                                   : Icons.visibility,
//                               color: Color(0xff332757),
//                             ),
//                             onPressed: () {
//                               setState(() {
//                                 _obscurePassword = !_obscurePassword;
//                               });
//                             },
//                           ),
//                         ),
//                       ),
//                       SizedBox(height: height * 0.015),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Row(
//                             children: [
//                               Checkbox(
//                                 activeColor: Color(0xff332757),
//                                 value: rememberMe,
//                                 onChanged: (value) {
//                                   setState(() {
//                                     rememberMe = value!;
//                                   });
//                                 },
//                               ),
//                               const Text("Remember Me"),
//                             ],
//                           ),
//                           TextButton(
//                             onPressed: () {},
//                             child: const Text(
//                               "Forgot Password?",
//                               style: TextStyle(
//                                 color: Color(0xff332757),
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       SizedBox(height: height * 0.025),
//
//                       // --------- Sign In Button ----------
//                       AnimatedContainer(
//                         duration: const Duration(milliseconds: 300),
//                         width: double.infinity,
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(15),
//                           color:Color(0xff332757) ,
//
//                         ),
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.transparent,
//                             shadowColor: Colors.transparent,
//                             padding: EdgeInsets.symmetric(
//                                 vertical: height * 0.018),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(15),
//                             ),
//                           ),
//                           onPressed: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                   builder: (context) => Dashboard()),
//                             );
//                           },
//                           child: Text(
//                             "Login",
//                             style: TextStyle(
//                               fontSize: width * 0.045,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       ),
//                       SizedBox(height: height * 0.01),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
