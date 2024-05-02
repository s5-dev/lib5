import 'base.dart';

class SimpleLogger extends Logger {
  final String prefix;
  final bool format;
  final bool showVerbose;

  SimpleLogger({
    this.prefix = '',
    this.format = true,
    this.showVerbose = false,
  });

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
    if (!showVerbose) return;
    print(prefix + s);
  }

  @override
  void warn(String s) {
    print('$prefix[warn] $s');
  }

  @override
  void catched(e, st, [context]) {
    warn(prefix + e.toString() + (context == null ? '' : ' [$context]'));
    print(prefix + st.toString());
  }
}
