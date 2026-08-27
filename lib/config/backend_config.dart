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

  /// Supabase project credentials (Replace with your actual Supabase credentials if available)
  static String supabaseUrl = 'https://ludokingdom.supabase.co';
  static String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1ZG9raW5nZG9tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDkzMTIwMDAsImV4cCI6MjAyNDg4ODAwMH0.placeholder';

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
