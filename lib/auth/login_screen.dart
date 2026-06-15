import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_helper/admin/adminBottombar/admin_bottombar.dart';
import 'package:print_helper/auth/forgot_pass.dart';
import 'package:print_helper/services/helpers.dart';
import 'package:provider/provider.dart';

import 'package:print_helper/constants/colors.dart';
import 'package:print_helper/constants/strings.dart';
import 'package:print_helper/widgets/custom_button.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:print_helper/widgets/spacers.dart';
import 'package:print_helper/widgets/text_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../admin/client/bottombar/client_bottombar.dart';
import '../admin/customers/bottombar/cust_bottombar.dart';
import '../admin/staff/bottombar/staff_bottombar.dart';
import '../constants/paths.dart';
import '../utils/regx.dart';
import '../providers/auth_pro.dart';
import '../widgets/field_widget.dart';
import '../widgets/toasts.dart';
import '../utils/console_util.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String selectedRole = "ADMIN";

  bool _remember = false;
  bool loading = false;
  bool showPassword = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
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
    printData(title: "LOGIN SUCCESS:", data: success);
    setState(() => loading = false);
    if (!success) return;
    await rememberMe();
    final role = authPro.user?.roleName ?? "";
    switch (role.toUpperCase()) {
      case "ADMIN": //SuperAdmin
        navTo(
          context: context,
          page: AdminBottomBar(pageNum: 0),
          removeUntil: true,
        );
        break;
      case "CONTACT": //Client
        navTo(
          context: context,
          page: ClientBottomBar(pageNum: 0),
          removeUntil: true,
        );
        break;
      case "STAFF": //Staff
        navTo(
          context: context,
          page: StaffBottomBar(pageNum: 0),
          removeUntil: true,
        );
        break;
      case "CUSTOMER":
        navTo(
          context: context,
          page: CustBottomBar(pageNum: 0),
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
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          selectedRole == "STAFF"
              ? Positioned.fill(
                  child: Image.asset(
                    Paths.whitebg,
                    fit: BoxFit.cover,
                    opacity: AlwaysStoppedAnimation(.35),
                  ),
                )
              : Positioned.fill(
                  child: ImageWidget(image: Paths.bgg, fit: BoxFit.cover),
                ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ImageWidget(
                      image: selectedRole == "STAFF"
                          ? Paths.logoBlck
                          : Paths.logoWhite,
                      width: 200,
                    ),
                    Container(
                      margin: EdgeInsets.fromLTRB(12.w, 15.h, 12.w, 0),
                      padding: EdgeInsets.fromLTRB(35.w, 30.h, 35.w, 20.h),
                      decoration: BoxDecoration(
                        color: const Color(0XFFf1f1f2),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 12.w),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextWidget(
                                text: "Hi,\nWelcome Back!",
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Spacers.sb10(),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _title("Username"),
                                CustomTextField(
                                  hintText: "Username",
                                  controller: _userCtrl,
                                  regExpCondition: Regx.userNameRegExp,
                                  errorText: AppStrings.usrNameError,
                                  regErrorText: AppStrings.usrNameError,
                                  bRadius: 15,
                                  fillColor: AppColors.white,
                                  filled: true,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 18.w,
                                    vertical: 12.h,
                                  ),
                                ),
                                Spacers.sb10(),
                                _title("Password"),
                                CustomTextField(
                                  controller: _passCtrl,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 18.w,
                                    vertical: 12.h,
                                  ),
                                  regExpCondition: Regx.optionalText,
                                  errorText: AppStrings.passError,
                                  hintText: "Password",
                                  bRadius: 15,
                                  regErrorText: AppStrings.passError,
                                  passField: true,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15.sp,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  fillColor: AppColors.fill,
                                  filled: true,
                                  isDence: true,
                                  obscureText: !showPassword,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => showPassword = !showPassword,
                                    ),
                                    icon: Icon(
                                      showPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      size: 20.w,
                                      color: AppColors.iconColor,
                                    ),
                                  ),
                                ),
                                Spacers.sb15(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => setState(
                                            () => _remember = !_remember,
                                          ),
                                          child: Container(
                                            width: 20.w,
                                            height: 20.w,
                                            decoration: BoxDecoration(
                                              color: _remember
                                                  ? const Color(0xFF00A650)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(15.r),
                                              border: Border.all(
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                            child: _remember
                                                ? Icon(
                                                    Icons.check,
                                                    size: 15.sp,
                                                    color: Colors.white,
                                                  )
                                                : null,
                                          ),
                                        ),
                                        Spacers.sbw8(),
                                        TextWidget(
                                          text: "Remember me",
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        navTo(
                                          context: context,
                                          page: ForgotPass(),
                                        );
                                      },
                                      child: TextWidget(
                                        text: "Forgot password?",
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Spacers.sb15(),
                                CustomButton(
                                  title: "Login",
                                  onTap: () async {
                                    await _onLoginTap(context);
                                  },
                                  height: 40,
                                  fontSize: 14,
                                  borderRadius: 15,
                                  buttonColor: const Color(0xff00a650),
                                  stadium: false,
                                ),
                                Spacers.sb15(),
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
          ),
        ],
      ),
    );
  }

  Padding _title(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 18.w, bottom: 5.h),
      child: TextWidget(text: text, fontSize: 14, fontWeight: FontWeight.w400),
    );
  }
}
