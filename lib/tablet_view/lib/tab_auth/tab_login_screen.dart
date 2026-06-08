import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_helper/providers/auth_pro.dart';
import '../tab_widgets/tab_custom_button.dart';
import '../tab_widgets/tab_toasts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tab_constants/colors.dart';
import '../tab_constants/paths.dart';
import '../tab_constants/strings.dart';
import '../tab_services/helpers.dart';
import '../tab_sidePanel/dashboard_wrapper.dart';
import '../tab_utils/regx.dart';
import '../tab_widgets/tab_field_widget.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_text_widget.dart';
import 'tab_forgot_pass.dart';

class TabLoginScreen extends StatefulWidget {
  const TabLoginScreen({super.key});

  @override
  State<TabLoginScreen> createState() => _TabLoginScreenState();
}

class _TabLoginScreenState extends State<TabLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String selectedRole = "ADMIN";
  final List<String> roles = ["ADMIN", "CLIENT", "STAFF", "CUSTOMER"];

  bool _remember = false;
  bool loading = false;
  bool showPassword = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
  }

  Future<void> _loadSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _remember = prefs.getBool("rememberMe") ?? false;

      if (_remember) {
        _userCtrl.text = prefs.getString("savedUsername") ?? "";
        _passCtrl.text = prefs.getString("savedPassword") ?? "";
      }
    });
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> rememberMe() async {
    final prefs = await SharedPreferences.getInstance();

    if (_remember) {
      await prefs.setBool("rememberMe", true);
      await prefs.setString("savedUsername", _userCtrl.text.trim());
      await prefs.setString("savedPassword", _passCtrl.text.trim());
    } else {
      await prefs.setBool("rememberMe", false);
      await prefs.remove("savedUsername");
      await prefs.remove("savedPassword");
    }
  }

  Future<void> _onLoginTap(dynamic context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    final authPro = Provider.of<AuthPro>(context, listen: false);

    final success = await authPro.loginUser(
      ctx: context,
      email: _userCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );
    debugPrint("LOGIN SUCCESS: $success");
    setState(() => loading = false);
    if (!success) return;
    // SAVE OR CLEAR REMEMBER ME
    await rememberMe();
    final role = authPro.user?.roleName ?? "";
    // final id = authPro.user?.id ?? "";
    debugPrint("User role: $role"); // print the role
    switch (role.toUpperCase()) {
      case "ADMIN":
        navTo(
          context: context,
          page: DashboardWrapper(role: "ADMIN"),
          removeUntil: true,
        );
        break;
      case "CONTACT":
        navTo(
          context: context,
          page: DashboardWrapper(role: "CONTACT"),
          removeUntil: true,
        );
        break;
      case "STAFF":
        navTo(
          context: context,
          page: DashboardWrapper(role: "STAFF"),
          removeUntil: true,
        );
        break;
      case "CUSTOMER":
        navTo(
          context: context,
          page: DashboardWrapper(role: "CUSTOMER"),
          removeUntil: true,
        );
        break;
      default:
        showToast(message: "Unknown role: $role");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // selectedRole == "STAFF"
          //     ?
          Positioned.fill(
            child: Image.asset(
              Paths.logBg,
              fit: BoxFit.fitWidth,
              opacity: AlwaysStoppedAnimation(.40),
            ),
          ),
          // : Positioned.fill(
          //     child: ImageWidget(image: Paths.logBg, fit: BoxFit.fitWidth),
          //   ),
          // Image.asset(Paths.bgg, fit: BoxFit.fitWidth),
          Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: .center,
                mainAxisAlignment: .center,
                children: [
                  ImageWidget(
                    image: selectedRole == "STAFF"
                        ? Paths.logoBlck
                        : Paths.logoWhite,
                    height: 60,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 400,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 35,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: 25.0),
                              child: Text(
                                "Hi,\nWelcome Back!",
                                textAlign: TextAlign.start,
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _title("Username"),
                            WebTextField(
                              hintText: "Username",
                              controller: _userCtrl,
                              regExpCondition: Regx.userNameRegExp,
                              errorText: AppStrings.usrNameError,
                              regErrorText: AppStrings.usrNameError,
                              bRadius: 15,
                              fillColor: AppColors.white,
                              filled: true,
                            ),
                            const SizedBox(height: 12),
                            _title("Password"),
                            WebTextField(
                              controller: _passCtrl,
                              regExpCondition: Regx.passwordRegExp,
                              errorText: AppStrings.passError,
                              hintText: "Password",
                              bRadius: 15,
                              regErrorText: AppStrings.passRegError,
                              passField: true,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              fillColor: AppColors.white,
                              filled: true,
                              obscureText: !showPassword,
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => showPassword = !showPassword,
                                ),
                                icon: Icon(
                                  showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 20,
                                  color: AppColors.iconColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _remember = !_remember,
                                      ),
                                      child: Container(
                                        margin: EdgeInsets.only(left: 6),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: _remember
                                              ? const Color(0xFF00A650)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                        child: _remember
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      "Remember me",
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () {
                                    navTo(
                                      context: context,
                                      page: TabForgotPass(),
                                    );
                                  },
                                  child: Text(
                                    "Forgot password?",
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            CustomButton(
                              title: "Login",
                              onTap: () async => await _onLoginTap(context),
                              height: 45,
                              fontSize: 15,
                              borderRadius: 15,
                              buttonColor: const Color(0xff00a650),
                              stadium: false,
                            ),
                            // SizedBox(
                            //   width: double.infinity,
                            //   height: 40,
                            //   child: ElevatedButton(
                            //     style: ElevatedButton.styleFrom(
                            //       backgroundColor: Colors.green,
                            //       shape: RoundedRectangleBorder(
                            //         borderRadius: BorderRadius.circular(14),
                            //       ),
                            //     ),
                            //     onPressed: () async => await _onLoginTap(context),
                            //     child: Text(
                            //       "Login",
                            //       style: GoogleFonts.poppins(
                            //         color: Colors.white,
                            //         fontSize: 15,
                            //         fontWeight: FontWeight.w500,
                            //       ),
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Padding _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 25, bottom: 5),
      child: TextWidget(text: text, fontSize: 14, fontWeight: FontWeight.w500),
    );
  }
}
