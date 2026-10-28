const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// `Wednesday 28 October`
String longDate(DateTime t) => '${_weekdays[t.weekday - 1]} ${t.day} ${_monthsLong[t.month - 1]}';

/// `Good morning`, `Good afternoon`, `Good evening`
String greeting(DateTime t) => t.hour < 12 ? 'Good morning' : (t.hour < 18 ? 'Good afternoon' : 'Good evening');

/// `14:05`
String clockTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// `Tue 28 Oct`
String shortDate(DateTime t) => '${_weekdays[t.weekday - 1].substring(0, 3)} ${t.day} ${_months[t.month - 1]}';

/// `just now`, `12 min ago`, `3 h ago`, `Tuesday`, `12 Oct`
String timeAgo(DateTime t, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return _weekdays[t.weekday - 1];
  return '${t.day} ${_months[t.month - 1]}';
}

/// The "since" in "2 new facts since Tuesday".
String sinceLabel(DateTime t, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final days = DateTime(today.year, today.month, today.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days <= 0) return 'since ${clockTime(t)}';
  if (days == 1) return 'since yesterday';
  if (days < 7) return 'since ${_weekdays[t.weekday - 1]}';
  return 'since ${t.day} ${_months[t.month - 1]}';
}

/// `9 min`, `1 h 12 min`, rounded to the nearest minute.
String durationLabel(Duration d) {
  final rounded = (d.inSeconds / 60).round();
  final minutes = rounded < 1 ? 1 : rounded;
  if (minutes < 60) return '$minutes min';
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60} h' : '${minutes ~/ 60} h $rest min';
}

/// `4:07` for players.
String playerTime(Duration d) => '${d.inMinutes}:${_two(d.inSeconds % 60)}';

/// `EN`, `DA`, `TA`
String languageLabel(String code) => code.toUpperCase();

String plural(int n, String singular, [String? pluralForm]) =>
    '$n ${n == 1 ? singular : (pluralForm ?? '${singular}s')}';
