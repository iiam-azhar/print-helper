class CustomException implements Exception {
  final String? message;
  final String? prefix;
  final String? url;

  CustomException([this.message, this.prefix, this.url]);
}

class FetchDataException extends CustomException {
  FetchDataException([String? message, String? url])
      : super(message, 'Error During Communication: ', url);
}

class BadRequestException extends CustomException {
  BadRequestException([String? message, String? url])
      : super(message, 'Invalid Request: ', url);
}

class UnauthorisedException extends CustomException {
  UnauthorisedException([String? message, String? url])
      : super(message, 'Unauthorised Request: ', url);
}

class InvalidInputException extends CustomException {
  InvalidInputException([String? message, String? url])
      : super(message, 'Invalid Input: ', url);
}

class ApiNotRespondingException extends CustomException {
  ApiNotRespondingException([String? message, String? url])
      : super(message, 'Api Not responding: ', url);
}

class ResourceNotFoundException extends CustomException {
  ResourceNotFoundException([String? message, String? url])
      : super(message, 'Resource Not Found: ', url);
}

class ServerErrorException extends CustomException {
  ServerErrorException([String? message, String? url])
      : super(message, 'Server Error: ', url);
}
