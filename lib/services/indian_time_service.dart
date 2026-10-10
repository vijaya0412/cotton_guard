/// Service resolving time and agricultural greetings based on Asia/Kolkata (IST = UTC+05:30).
class IndianTimeService {
  /// Resolves the current DateTime in Indian Standard Time (IST, UTC+5:30).
  /// An optional [referenceTime] can be supplied for unit testing.
  static DateTime nowInIndia([DateTime? referenceTime]) {
    final base = referenceTime ?? DateTime.now();
    return base.toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  /// Returns the appropriate period greeting based on Indian local time:
  /// - 05:00–11:59: "Good morning"
  /// - 12:00–16:59: "Good afternoon"
  /// - 17:00–20:59: "Good evening"
  /// - 21:00–04:59: "Good night"
  static String getGreeting([DateTime? referenceTime]) {
    final ist = nowInIndia(referenceTime);
    final totalMinutes = ist.hour * 60 + ist.minute;

    // 05:00 (300 min) to 11:59 (719 min)
    if (totalMinutes >= 5 * 60 && totalMinutes < 12 * 60) {
      return 'Good morning';
    }
    // 12:00 (720 min) to 16:59 (1019 min)
    if (totalMinutes >= 12 * 60 && totalMinutes < 17 * 60) {
      return 'Good afternoon';
    }
    // 17:00 (1020 min) to 20:59 (1259 min)
    if (totalMinutes >= 17 * 60 && totalMinutes < 21 * 60) {
      return 'Good evening';
    }
    // 21:00 (1260 min) to 04:59 (299 min)
    return 'Good night';
  }

  /// Returns the greeting period identifier ('morning', 'afternoon', 'evening', 'night').
  /// Useful to detect period transitions without unnecessary UI rebuilds.
  static String getGreetingPeriod([DateTime? referenceTime]) {
    final ist = nowInIndia(referenceTime);
    final totalMinutes = ist.hour * 60 + ist.minute;

    if (totalMinutes >= 5 * 60 && totalMinutes < 12 * 60) return 'morning';
    if (totalMinutes >= 12 * 60 && totalMinutes < 17 * 60) return 'afternoon';
    if (totalMinutes >= 17 * 60 && totalMinutes < 21 * 60) return 'evening';
    return 'night';
  }
}
