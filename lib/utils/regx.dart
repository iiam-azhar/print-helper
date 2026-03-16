class Regx {
  static final nameRegExp = RegExp(r'^\s*[a-zA-Z]+\s*$');
  static final fullNameRegExp = RegExp(r'^[A-Za-z\s]+$');
  static final emailPhoneRegExp = RegExp(
    r'^(?:(\S+@\S+\.\S+)|(?:[1-9]\d{8}|0\d{9}))$',
  );
  static final emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final phoneRegExp = RegExp(r'^\+?[0-9]{10,15}$');
  static final addressRegExp = RegExp(r'^[a-zA-Z0-9\s.,-]*$');
  static final eightDigitRegExp = RegExp(r'^\d{8}$');
  static final fiveDigitRegExp = RegExp(r'^\d{5}$');
  static final sixDigitRegExp = RegExp(r'^\d{6}$');
  static final zipcodeRegExp = RegExp(r'^\d{4,10}$');
  // ensures 0 can be added at front
  // static final nineDigitRegExp = RegExp(r'^(?:[1-9]\d{8}|0\d{9})$');
  static final passwordRegExp = RegExp(
    r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[\W_]).{8,}$',
  );
  static final optionalPasswordRegExp = RegExp(
    r'^$|^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[\W_]).{8,}$',
  );
  static final doubleRegExp = RegExp(r'^\d+(\.\d+)?$');
  // enusres double with eg-> 100, 100.00 , 100.,
  static final double2RegExp = RegExp(r'^\d+\.?\d{0,2}');
  static final userNameRegExp = RegExp(
    r'^[a-zA-Z](?!.*[._@]{2})[a-zA-Z0-9._@]{2,29}$',
  );
  static final optionalText = RegExp(r'.*');
  // static final oldEmailRegExp =  RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$');
  // static final nameRegExp = RegExp(r'^[a-zA-Z]+$');
  // static final eightDigitRegExp = RegExp(r'^\d{8}$');
  // static final nineDigitRegExp = RegExp(r'^\d{9,}$'); // min 9 digit
  // static final passwordRegExp = RegExp(r'.{8,}');
}
