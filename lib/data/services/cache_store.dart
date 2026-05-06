/// Platform-aware cache store.
/// On Web: in-memory (cache_store_web.dart)
/// On native: SQLite via sqflite (cache_store_native.dart)
export 'cache_store_native.dart'
    if (dart.library.html) 'cache_store_web.dart';
