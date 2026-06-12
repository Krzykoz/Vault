/// A source of the current time. Inject this instead of calling
/// `DateTime.now()` directly so time-dependent logic (cache TTLs) stays testable.
abstract interface class Clock {
  DateTime now();
}
