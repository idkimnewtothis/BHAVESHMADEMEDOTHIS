import 'dart:async';
import 'dart:collection';

/// Limits whole chapter/episode jobs, including preparation and retries.
class WorkQueue {
  final int concurrency;
  final Future<void> Function(int) run;
  final void Function(int, Object, StackTrace) onError;
  final _pending = Queue<int>();
  final _active = <int>{};
  bool _closed = false;
  WorkQueue({required this.run, required this.onError, this.concurrency = 2}) {
    if (concurrency < 1) throw ArgumentError.value(concurrency);
  }
  void add(int id) {
    if (_closed || _active.contains(id) || _pending.contains(id)) return;
    _pending.add(id);
    _pump();
  }

  void remove(int id) => _pending.remove(id);
  void close() {
    _closed = true;
    _pending.clear();
  }

  void _pump() {
    while (!_closed && _active.length < concurrency && _pending.isNotEmpty) {
      final id = _pending.removeFirst();
      _active.add(id);
      unawaited(
        Future<void>(() => run(id))
            .catchError((Object e, StackTrace st) {
              onError(id, e, st);
            })
            .whenComplete(() {
              _active.remove(id);
              _pump();
            }),
      );
    }
  }
}
