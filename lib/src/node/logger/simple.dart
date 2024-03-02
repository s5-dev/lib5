import 'base.dart';

class SimpleLogger extends Logger {
  final String prefix;
  final bool format;

  SimpleLogger({this.prefix = '', this.format = true});

  @override
  void info(String s) {
    print(prefix + s.replaceAll(RegExp('\u001b\\[\\d+m'), ''));
  }

  @override
  void error(String s) {
    print('$prefix[ERROR] $s');
  }

  @override
  void verbose(String s) {
    print(prefix + s);
  }

  @override
  void warn(String s) {
    print('$prefix[warn] $s');
  }

  @override
  void catched(e, st, [context]) {
    warn(prefix + e.toString() + (context == null ? '' : ' [$context]'));
    verbose(prefix + st.toString());
  }
}
