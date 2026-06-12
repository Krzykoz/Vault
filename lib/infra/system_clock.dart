import '../core/ports/clock.dart';

/// [Clock] backed by the system clock, returning UTC time.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
