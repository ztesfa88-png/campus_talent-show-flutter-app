/// In-memory cache store for Web (sqflite/path_provider not available).
/// Data is lost when the page is refreshed — acceptable for Web.

class CacheEntry {
  final String payload;
  final int updatedAt;
  const CacheEntry({required this.payload, required this.updatedAt});
}

class CacheStore {
  final Map<String, CacheEntry> _cache = {};
  final List<Map<String, dynamic>> _queue = [];
  int _nextId = 1;

  Future<void> write(String key, String payload) async {
    _cache[key] = CacheEntry(
      payload: payload,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<CacheEntry?> read(String key) async => _cache[key];

  Future<void> enqueue(String actionType, String payload) async {
    _queue.add({
      'id': _nextId++,
      'action_type': actionType,
      'payload': payload,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retry_count': 0,
    });
  }

  Future<List<Map<String, dynamic>>> pendingActions() async =>
      List.unmodifiable(_queue);

  Future<int> pendingCount() async => _queue.length;

  Future<void> dequeue(int id) async =>
      _queue.removeWhere((r) => r['id'] == id);

  Future<void> incrementRetry(int id) async {
    final idx = _queue.indexWhere((r) => r['id'] == id);
    if (idx != -1) {
      _queue[idx] = {
        ..._queue[idx],
        'retry_count': (_queue[idx]['retry_count'] as int) + 1,
      };
    }
  }
}
