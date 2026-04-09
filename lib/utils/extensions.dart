extension NumberParsing on dynamic {
  int get toInt => (int.tryParse(this) ?? 0);
  double get toDouble => (double.tryParse('$this') ?? 0);
  bool get isString => (int.tryParse('$this') ?? 0) == 0;
  String get toNrString {
    String str = toString();
    String input = '${(double.tryParse(str) ?? 0.00)}';
    List<String> numParts = input.split('.');
    bool hasDcml = numParts.length > 1;
    String intgr = numParts[0];
    String dcml = hasDcml ? numParts[1].padRight(2, '0').substring(0, 2) : '00';
    String nrNum = '$intgr.$dcml';

    return nrNum;
  }
}

extension StringExtension on String {
  String get capitalize {
    if (isEmpty) {
      return this;
    }
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  String get toTitleCase {
    if (isEmpty) {
      return this;
    }
    return replaceAll(RegExp(' +'), ' ')
        .split(' ')
        .map((str) => str.capitalize)
        .join(' ');
  }

  String get removeSpaces {
    if (isEmpty) {
      return this;
    }
    return replaceAll(RegExp(r'\s+'), '');
  }

  String get initials {
    final words = split(' ');
    final initials = words
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
        .join();
    return initials.length > 2 ? initials.substring(0, 2) : initials;
  }
}

extension UriExtensions on Uri {
  String get fileName {
    String name = pathSegments.isNotEmpty ? pathSegments.last : 'file_${DateTime.now().millisecondsSinceEpoch}';
    // Remove query parameters if they're somehow included (though Uri.parse shouldn't)
    if (name.contains('?')) {
      name = name.split('?').first;
    }
    // Limit length to avoid OS errors (errno 36)
    if (name.length > 100) {
      final ext = name.contains('.') ? name.split('.').last : '';
      final base = name.contains('.') ? name.split('.').first : name;
      name = "${base.substring(0, 50)}_${DateTime.now().millisecondsSinceEpoch}${ext.isNotEmpty ? '.$ext' : ''}";
    }
    return name;
  }

  String get fileType {
    final url = toString().split('?').first;
    return url.split('.').last;
  }
}
