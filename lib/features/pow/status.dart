/// Connect phases (desktop `pow/status.py` PowPhase).
enum PowPhase {
  idle,
  starting,
  outer,
  inner,
  bridging,
  connected,
  failed,
}

/// Background watchdog states of the Vyrax Free tunnel.
///
/// `ready` from the spec maps to [healthy]: a healthy server was found and
/// the tunnel is serving it. `manual disconnect` maps to [disabled] until the
/// next explicit Connect, so the watchdog never self-heals against user will.
enum PowHealthState {
  /// Watchdog off: nothing running, or the user disconnected / removed.
  disabled,

  /// Connected and the last exit probe succeeded (ready).
  healthy,

  /// One health probe is in flight.
  checking,

  /// The server went away; an automatic rescan/discovery is running.
  recovering,

  /// No healthy server was found (or the rescan errored); the automatic
  /// recovery gave up or is waiting for its next backoff window.
  failed,
}

enum PowStepState { running, done, failed }

class PowStep {
  const PowStep(this.text, this.state);

  final String text;
  final PowStepState state;
}

class PowStatus {
  const PowStatus({
    this.phase = PowPhase.idle,
    this.progress = 0,
    this.detail = '',
    this.outerLabel = '',
    this.exitRegion = '',
    this.steps = const [],
  });

  final PowPhase phase;
  final int progress;
  final String detail;
  final String outerLabel;
  final String exitRegion;
  final List<PowStep> steps;
}

/// Maps a native scan line to a `Scan <addr> <outcome>` step line.
String? scanPulse(String message) {
  final text = message.trim();
  if (text.startsWith('Scanning ')) {
    final rest = text.substring('Scanning '.length);
    var addr = rest;
    if (rest.contains(' via ')) {
      addr = rest.split(' via ')[0].trim();
    } else {
      final words = rest.split(' ');
      if (words.isNotEmpty) {
        addr = words[0];
      }
    }
    return 'Scan ${addr.trim()} trying';
  }
  if (!text.startsWith('Rejected ')) return null;
  final body = text.substring('Rejected '.length);
  var addr = body;
  if (body.contains(': ')) {
    addr = body.split(': ')[0];
  } else {
    final words = body.split(' ');
    if (words.isNotEmpty) addr = words[0];
  }
  addr = addr.trim();
  String why;
  final lower = text.toLowerCase();
  if (text.contains('status 400')) {
    why = '400';
  } else if (text.contains('ACCESS_DENIED')) {
    why = 'access-denied';
  } else if (text.contains('CERTIFICATE')) {
    why = 'certificate';
  } else if (lower.contains('timeout')) {
    why = 'timeout';
  } else if (lower.contains('reset')) {
    why = 'reset';
  } else if (text.contains('unexpected EOF')) {
    why = 'eof';
  } else {
    why = 'other';
  }
  return 'Scan $addr $why';
}

/// Maps a native log line to a user-facing step line (mobile parity).
String? stageLine(String message) {
  final text = (message).trim();
  if (text.startsWith('Key:')) {
    return 'Key ${text.substring(4).trim()}';
  }
  if (text.startsWith('Cert:')) {
    return 'Cert ${text.substring(5).trim()}';
  }
  if (text.startsWith('Clean HTTP/2 list:')) return text;
  if (text.startsWith('Clean HTTP/2 list is empty. Starting')) {
    return 'Clean list empty. HTTP/2 scan is starting.';
  }
  if (text.startsWith('Trying saved clean address')) return text;
  if (text.startsWith('Saved clean address accepted')) return text;
  if (text.startsWith('Saved clean address rejected')) return text;
  if (text.startsWith('Every saved address failed. Scan was not started')) {
    return text;
  }
  if (text.startsWith('Every saved address failed. Starting')) {
    return 'Saved addresses failed. HTTP/2 scan is starting.';
  }
  if (text.startsWith('Scanning HTTP/2')) return text;
  if (text.startsWith('Saved clean HTTP/2 address')) return text;
  if (text.startsWith('Scanning ') || text.startsWith('Rejected ')) {
    return scanPulse(text);
  }
  if (text.startsWith('HTTP/2 selected')) return 'HTTP/2 started';
  if (text.startsWith('MASQUE accepted')) return text;
  if (text.startsWith('MASQUE start')) return text;
  if (text.startsWith('Tunnel did not stay up')) return text;
  if (text.startsWith('MASQUE: dialing known gateways on UDP/1701')) {
    return 'Trying UDP/1701';
  }
  if (text.startsWith('MASQUE: no known gateway accepted UDP/1701')) {
    return 'UDP/1701 did not answer';
  }
  if (text.startsWith('MASQUE: UDP/1701 did not answer')) {
    return 'UDP/1701 did not answer, trying TCP';
  }
  if (text.startsWith('No usable MASQUE')) return text;
  if (text.startsWith('MASQUE identity refused')) {
    return 'Certificate refused. Requesting a new one.';
  }
  if (text.startsWith('Certificate ')) return text;
  if (text.startsWith('This certificate was refused')) return text;
  if (text.startsWith('New certificate saved')) return text;
  if (text.startsWith('New MASQUE certificate issued')) {
    return 'New certificate issued. Retrying the gateways.';
  }
  if (text.startsWith('Could not refresh the MASQUE certificate')) return text;
  if (text.startsWith('PSIPHON ')) return text;
  return null;
}
/// Connect-steps store with change notifications (mobile `PowStatusStore`).
class PowStatusStore {
  PowStatus _status = const PowStatus();
  final _listeners = <void Function(PowStatus)>[];

  PowStatus get snapshot => _status;

  void addListener(void Function(PowStatus) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(PowStatus) listener) {
    _listeners.remove(listener);
  }

  void _emit() {
    final snapshot = _status;
    for (final listener in List.of(_listeners)) {
      try {
        listener(snapshot);
      } catch (_) {
        // listener errors never break the connect flow
      }
    }
  }

  void update(
    PowPhase phase,
    int progress,
    String detail, {
    String? outerLabel,
    String? exitRegion,
  }) {
    _status = PowStatus(
      phase: phase,
      progress: progress.clamp(0, 100).toInt(),
      detail: detail,
      outerLabel: outerLabel ?? _status.outerLabel,
      exitRegion: exitRegion ?? _status.exitRegion,
      steps: _status.steps,
    );
    var changed = false;
    if (detail.trim().isNotEmpty) {
      changed = _noteLocked(detail) || changed;
    }
    if (phase == PowPhase.connected) {
      changed = _finishLocked(PowStepState.done) || changed;
    }
    if (phase == PowPhase.failed) {
      changed = _finishLocked(PowStepState.failed) || changed;
    }
    _emit();
  }

  void pulse(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final capped = _cap(clean);
    final steps = List.of(_status.steps);
    final last = steps.isEmpty ? null : steps.last;
    if (last != null &&
        last.state == PowStepState.running &&
        last.text.startsWith('Scan ')) {
      if (last.text == capped) return;
      steps[steps.length - 1] = PowStep(capped, last.state);
    } else {
      if (!_noteLocked(clean)) return;
    }
    _status = PowStatus(
      phase: _status.phase,
      progress: _status.progress,
      detail: _status.detail,
      outerLabel: _status.outerLabel,
      exitRegion: _status.exitRegion,
      steps: steps,
    );
    _emit();
  }

  void scan(String text, String outcome) {
    final clean = _cap(text.trim());
    if (clean.isEmpty) return;
    final state = outcome == 'trying'
        ? PowStepState.running
        : outcome == 'accepted'
            ? PowStepState.done
            : PowStepState.failed;
    final steps = List.of(_status.steps);
    final last = steps.isEmpty ? null : steps.last;
    if (last != null &&
        last.state == PowStepState.running &&
        last.text.startsWith('Scan ')) {
      steps[steps.length - 1] = PowStep(clean, state);
    } else {
      if (last != null && last.state == PowStepState.running) {
        steps[steps.length - 1] = PowStep(last.text, PowStepState.done);
      }
      steps.add(PowStep(clean, state));
      _status = PowStatus(
        phase: _status.phase,
        progress: _status.progress,
        detail: _status.detail,
        outerLabel: _status.outerLabel,
        exitRegion: _status.exitRegion,
        steps: steps.sublist(steps.length > 24 ? steps.length - 24 : 0),
      );
      _emit();
      return;
    }
    _status = PowStatus(
      phase: _status.phase,
      progress: _status.progress,
      detail: _status.detail,
      outerLabel: _status.outerLabel,
      exitRegion: _status.exitRegion,
      steps: steps,
    );
    _emit();
  }

  void note(String text, [bool failed = false]) {
    if (_noteLocked(text, failed)) {
      _emit();
    }
  }

  bool _noteLocked(String text, [bool failed = false]) {
    final clean = _cap(text.trim());
    if (clean.isEmpty) return false;
    final steps = List.of(_status.steps);
    final last = steps.isEmpty ? null : steps.last;
    if (last != null && last.text == clean) return false;
    if (last != null && last.state == PowStepState.running) {
      steps[steps.length - 1] = PowStep(last.text, PowStepState.done);
    }
    steps.add(
      PowStep(clean, failed ? PowStepState.failed : PowStepState.running),
    );
    _status = PowStatus(
      phase: _status.phase,
      progress: _status.progress,
      detail: _status.detail,
      outerLabel: _status.outerLabel,
      exitRegion: _status.exitRegion,
      steps: steps.sublist(steps.length > 24 ? steps.length - 24 : 0),
    );
    return true;
  }

  bool _finishLocked(PowStepState state) {
    final steps = List.of(_status.steps);
    if (steps.isEmpty || steps.last.state != PowStepState.running) {
      return false;
    }
    steps[steps.length - 1] = PowStep(steps.last.text, state);
    _status = PowStatus(
      phase: _status.phase,
      progress: _status.progress,
      detail: _status.detail,
      outerLabel: _status.outerLabel,
      exitRegion: _status.exitRegion,
      steps: steps,
    );
    return true;
  }

  void reset() {
    _status = const PowStatus();
    _emit();
  }
}

const _maxStepLength = 180;

String _cap(String text) => text.length > _maxStepLength
    ? text.substring(0, _maxStepLength)
    : text;
