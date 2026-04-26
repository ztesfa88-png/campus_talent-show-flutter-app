import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/widgets/base_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://uxtphyxmingappmskery.supabase.co',
    anonKey: 'sb_publishable_El_io8r2fFzZoDa-RW7c9g_3erC_c3l',
  );

  runApp(const ProviderScope(child: BaseApp()));
}
