import 'package:flutter/foundation.dart';

enum BackendMode {
  /// Default: Primary Firebase with instant automatic failover to Supabase & dual-cloud mirroring
  hybridAutoFailover,

  /// Enforce Firebase Cloud only
  firebaseOnly,

  /// Enforce Supabase Cloud only
  supabaseOnly,
}

class BackendConfig {
  /// Active operating mode
  static BackendMode backendMode = BackendMode.hybridAutoFailover;

  /// Supabase project credentials
  static String supabaseUrl = 'https://qnxmdslhixdmzujdjaoj.supabase.co';
  static String supabaseAnonKey =
      'sb_publishable_SeX9TxJqbgdAjG6sin70Uw_DsnpFHNR';

  /// Whether Supabase credentials are valid and active
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('placeholder') &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.contains('placeholder');

  /// Runtime provider status
  static final ValueNotifier<String> activeBackendProvider =
      ValueNotifier<String>('Firebase (Primary)');

  /// Update active backend indicator
  static void setActiveProvider(String name) {
    activeBackendProvider.value = name;
  }
}
