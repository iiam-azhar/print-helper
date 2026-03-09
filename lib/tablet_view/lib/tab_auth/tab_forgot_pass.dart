import 'package:flutter/material.dart';
import 'package:print_helper/auth/login_screen.dart';
import 'package:print_helper/auth/reset_pass.dart';
import '../tab_services/helpers.dart';

import '../tab_constants/colors.dart';
import '../tab_constants/strings.dart';
import '../tab_widgets/tab_custom_button.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_spacers.dart';
import '../tab_widgets/tab_text_widget.dart';
import '../tab_widgets/tab_toasts.dart';

import '../tab_constants/paths.dart';
import '../tab_utils/regx.dart';
import '../tab_widgets/tab_field_widget.dart';

class TabForgotPass extends StatefulWidget {
  const TabForgotPass({super.key});
  @override
  State<TabForgotPass> createState() => _TabForgotPassState();
}

class _TabForgotPassState extends State<TabForgotPass> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool loading = false;
  bool showPassword = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              Paths.logBg,
              fit: BoxFit.fitWidth,
              opacity: AlwaysStoppedAnimation(.40),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: .center,
                mainAxisAlignment: .center,
                children: [
                  ImageWidget(image: Paths.logoWhite, height: 60),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 400,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 35,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0XFFf1f1f2),
                        borderRadius: BorderRadius.circular(20),
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
                            padding: EdgeInsets.only(left: 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextWidget(
                                text: "Forgot\nPassword?",
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Spacers.sb10(),
                          Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: TextWidget(
                              text:
                                  "No worries! It happens. Please enter your email and we will send you a OTP to reset your password.",
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.black87,
                            ),
                          ),
                          Spacers.sb12(),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _title("Email Address"),
                                CustomTextField(
                                  hintText: "Enter your email",
                                  controller: _emailCtrl,
                                  regExpCondition: Regx.emailRegExp,
                                  errorText: AppStrings.emailError,
                                  regErrorText: AppStrings.emailRegError,
                                  bRadius: 15,
                                  fillColor: AppColors.white,
                                  filled: true,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                ),
                                Spacers.sb15(),
                                _sendOtp(context),
                                Spacers.sb10(),
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      navTo(
                                        context: context,
                                        page: const LoginScreen(),
                                        removeUntil: true,
                                      );
                                    },
                                    child: TextWidget(
                                      text: 'Back to Login',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
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
        ],
      ),
    );
  }

  Widget _sendOtp(dynamic context) {
    return CustomButton(
      title: "Send OTP",
      onTap: () async {
        FocusScope.of(context).unfocus();
        bool isValid = _formKey.currentState!.validate();
        if (isValid) {
          final authPro = getAuthPro(context);
          final success = await authPro.forgetPassword(
            email: _emailCtrl.text.trim(),
            context: context,
          );
          if (success) {
            navTo(
              context: context,
              page: ResetPass(email: _emailCtrl.text.trim()),
            );
          } else {
            showToast(message: 'OTP failed');
          }
        }
      },
      height: 40,
      fontSize: 14,
      borderRadius: 15,
      buttonColor: const Color(0xff00a650),
      stadium: false,
    );
  }

  Padding _title(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 18, bottom: 5),
      child: TextWidget(
        text: text,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
    );
  }
}
