import 'dart:async';

import 'package:delayed_display/delayed_display.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_helper/auth/login_screen.dart';

import '../tab_constants/colors.dart';
import '../tab_constants/strings.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_spacers.dart';
import '../tab_widgets/tab_text_widget.dart';

import '../tab_constants/paths.dart';
import '../tab_services/helpers.dart';
import '../tab_utils/regx.dart';
import '../tab_widgets/tab_custom_button.dart';
import '../tab_widgets/tab_field_widget.dart';
import '../tab_widgets/tab_toasts.dart';

class ResetPass extends StatefulWidget {
  final String email;
  const ResetPass({super.key, required this.email});
  @override
  State<ResetPass> createState() => _ResetPassState();
}

class _ResetPassState extends State<ResetPass> {
  final _fieldOne = TextEditingController();
  final _fieldTwo = TextEditingController();
  final _fieldThree = TextEditingController();
  final _fieldFour = TextEditingController();
  final _fieldFive = TextEditingController();
  final _fieldSix = TextEditingController();
  final psswrdCntrlr = TextEditingController();
  final confirmPassCntrlr = TextEditingController();
  final _f1 = FocusNode();
  final _f2 = FocusNode();
  final _f3 = FocusNode();
  final _f4 = FocusNode();
  final _f5 = FocusNode();
  final _f6 = FocusNode();
  final _newPassKey = GlobalKey<FormState>();
  final _otpKey = GlobalKey<FormState>();
  bool showPassword = false;
  bool showConfirmPassword = false;
  int secondsRemaining = 30;
  bool enableResend = false;
  bool isOtpVerified = false;
  bool isLoading = false;
  late Timer timer;
  Map<TextEditingController, bool> _digitObscure = {};
  @override
  void initState() {
    super.initState();
    _digitObscure = {
      _fieldOne: true,
      _fieldTwo: true,
      _fieldThree: true,
      _fieldFour: true,
      _fieldFive: true,
      _fieldSix: true,
    };
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (secondsRemaining != 0) {
        setState(() {
          secondsRemaining--;
        });
      } else {
        setState(() {
          enableResend = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
                  Container(
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
                              text: "Reset\nPassword?",
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Spacers.sb10(),
                        _otpTxt(),
                        otpField(),
                        if (!isOtpVerified) resendOtp(),
                        if (isOtpVerified) _passwordFields(),
                        Spacers.sb30(),
                        _submitBtn(context),
                      ],
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

  Widget _otpTxt() {
    return RichText(
      textAlign: TextAlign.start,
      text: TextSpan(
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
        children: [
          TextSpan(
            text: 'Enter the OTP sent to ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          TextSpan(
            text: maskEmail(widget.email),
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          TextSpan(
            text: ' to reset your password.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String maskEmail(String email) {
    if (email.isEmpty || !email.contains("@")) return email;
    int atIndex = email.indexOf("@");
    String username = email.substring(0, atIndex);
    String domain = email.substring(atIndex);
    if (username.length <= 2) {
      return "${username[0]}*${username[1]}$domain";
    }
    String first = username[0];
    String last = username[username.length - 1];
    String stars = "*" * (username.length - 2);
    return "$first$stars$last$domain";
  }

  Widget _passwordFields() {
    return DelayedDisplay(
      child: Form(
        key: _newPassKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              regExpCondition: Regx.passwordRegExp,
              controller: psswrdCntrlr,
              hintText: 'New password',
              errorText: AppStrings.passError,
              regErrorText: AppStrings.passRegError,
              passField: true,
              bRadius: 14,
              padding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              fillColor: AppColors.white,
              filled: true,
              isDence: true,
              obscureText: !showPassword,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    showPassword = !showPassword;
                  });
                },
                icon: Icon(
                  showPassword ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: AppColors.iconColor,
                ),
              ),
            ),
            Spacers.sb10(),
            CustomTextField(
              regExpCondition: Regx.passwordRegExp,
              controller: confirmPassCntrlr,
              errorText: AppStrings.passError,
              regErrorText: AppStrings.passRegError,
              hintText: 'Confirm password',
              bRadius: 14,
              passField: true,
              padding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              fillColor: AppColors.white,
              filled: true,
              isDence: true,
              obscureText: !showConfirmPassword,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    showConfirmPassword = !showConfirmPassword;
                  });
                },
                icon: Icon(
                  showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: AppColors.iconColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget otpField() {
    return Column(
      children: [
        Spacers.sb15(),
        Form(
          key: _otpKey,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              otpInput(
                _fieldOne,
                context: context,
                autoFocus: true,
                focusNode: _f1,
                nextFocus: _f2,
              ),
              Spacers.sbw5(),
              otpInput(
                _fieldTwo,
                context: context,
                autoFocus: false,
                focusNode: _f2,
                prevFocus: _f1,
                nextFocus: _f3,
              ),
              Spacers.sbw5(),
              otpInput(
                _fieldThree,
                context: context,
                autoFocus: false,
                focusNode: _f3,
                prevFocus: _f2,
                nextFocus: _f4,
              ),
              Spacers.sbw5(),
              otpInput(
                _fieldFour,
                context: context,
                autoFocus: false,
                focusNode: _f4,
                prevFocus: _f3,
                nextFocus: _f5,
              ),
              Spacers.sbw5(),
              otpInput(
                _fieldFive,
                context: context,
                autoFocus: false,
                focusNode: _f5,
                prevFocus: _f4,
                nextFocus: _f6,
              ),
              Spacers.sbw5(),
              otpInput(
                _fieldSix,
                context: context,
                autoFocus: false,
                focusNode: _f6,
                prevFocus: _f5,
              ),
            ],
          ),
        ),
        if (isOtpVerified)
          Padding(
            padding: EdgeInsets.only(left: 30.0, top: 8),
            child: Row(
              children: [
                Icon(Icons.done, color: Colors.green, size: 20),
                TextWidget(
                  text: 'OTP Verified',
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
          ),
        Spacers.sb30(),
      ],
    );
  }

  Widget resendOtp() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: AppStrings.notReceive,
            style: const TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            children: <TextSpan>[
              TextSpan(
                text: AppStrings.resendCode,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: secondsRemaining == 0
                      ? AppColors.black
                      : Colors.black38,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    enableResend ? resendCode() : null;
                  },
              ),
            ],
          ),
        ),
        Spacers.sb5(),
        if (secondsRemaining != 0)
          TextWidget(
            text:
                '${AppStrings.resendOtpIn} $secondsRemaining ${AppStrings.seconds}',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
      ],
    );
  }

  Widget _submitBtn(dynamic context) {
    return CustomButton(
      height: 40,
      fontSize: 14,
      borderRadius: 15,
      buttonColor: const Color(0xff00a650),
      stadium: false,
      title: isOtpVerified ? AppStrings.submit : "Verify OTP",
      textColor: AppColors.white,
      borderColor: AppColors.white,
      borderWidth: 2,
      viewCase: ViewCase.upper,
      onTap: () async {
        final authPro = getAuthPro(context);
        if (!isOtpVerified) {
          // Step 1: Validate OTP
          dismissInputFocus();
          if (_otpKey.currentState!.validate()) {
            setState(() => isLoading = true);
            String enteredOTP =
                '${_fieldOne.text}${_fieldTwo.text}${_fieldThree.text}${_fieldFour.text}${_fieldFive.text}${_fieldSix.text}';
            bool otpValid = await authPro.validateOtpApi(
              email: widget.email,
              otp: enteredOTP,
              context: context,
            );
            setState(() => isLoading = false);
            if (otpValid) {
              setState(() => isOtpVerified = true);
            } else {
              showToast(message: 'Invalid OTP. Please try again.');
            }
          }
        } else {
          if (_newPassKey.currentState!.validate()) {
            if (psswrdCntrlr.text != confirmPassCntrlr.text) {
              showToast(message: AppStrings.urBothPassDfrnt);
              return;
            }
            setState(() => isLoading = true);
            bool resetDone = await authPro.resetPass(
              password: psswrdCntrlr.text,
              context: context,
              otp:
                  '${_fieldOne.text}${_fieldTwo.text}${_fieldThree.text}${_fieldFour.text}${_fieldFive.text}${_fieldSix.text}',
            );
            setState(() => isLoading = false);
            if (resetDone) {
              showToast(
                message: "Password reset successfully.",
              ).whenComplete(() {
                navTo(context: context, page: LoginScreen(), removeUntil: true);
              });
            } else {
              showToast(message: "Failed to reset password.");
            }
          }
        }
      },
    );
  }

  Widget otpInput(
    TextEditingController controller, {
    required context,
    required bool autoFocus,
    FocusNode? focusNode,
    FocusNode? prevFocus,
    FocusNode? nextFocus,
  }) {
    return Expanded(
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty &&
              prevFocus != null) {
            FocusScope.of(context).requestFocus(prevFocus);
          }
        },
        child: TextFormField(
          focusNode: focusNode,
          readOnly: isOtpVerified,
          autofocus: autoFocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          autovalidateMode: AutovalidateMode.always,
          controller: controller,
          maxLength: 1,
          obscureText: _digitObscure[controller] ?? true,
          obscuringCharacter: "•",
          style: GoogleFonts.josefinSans(fontSize: 21),
          decoration: InputDecoration(
            errorStyle: const TextStyle(fontSize: 0.01),
            filled: true,
            isDense: true,
            fillColor: const Color(0xffEEEEEE),
            counterText: '',
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.red, width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.red, width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            hintStyle: GoogleFonts.josefinSans(
              color: Colors.black,
              fontSize: 20.0,
            ),
          ),
          validator: (value) {
            if (value!.trim().isEmpty) {
              return 'error';
            }
            return null;
          },
          onChanged: (value) {
            if (value.isNotEmpty) {
              setState(() => _digitObscure[controller] = false);
              Future.delayed(const Duration(milliseconds: 600), () {
                if (mounted) {
                  setState(() => _digitObscure[controller] = true);
                }
              });
            }
            if (value.length == 1) {
              if (nextFocus != null) {
                FocusScope.of(context).requestFocus(nextFocus);
              }
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer.cancel();
    _f1.dispose();
    _f2.dispose();
    _f3.dispose();
    _f4.dispose();
    _f5.dispose();
    _f6.dispose();
    super.dispose();
  }

  Future<void> resendCode() async {
    final authPro = getAuthPro(context);
    await authPro.forgetPassword(email: widget.email, context: context);
    _fieldOne.clear();
    _fieldTwo.clear();
    _fieldThree.clear();
    _fieldFour.clear();
    _fieldFive.clear();
    _fieldSix.clear();
    setState(() {
      secondsRemaining = 30;
      enableResend = false;
    });
  }
}
