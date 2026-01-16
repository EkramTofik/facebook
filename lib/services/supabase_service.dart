import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// SupabaseService handles global access to the Supabase client.
/// This prevents us from having to call `Supabase.instance.client` everywhere.
class SupabaseService {
  
  /// getter to access the Supabase client instance easily
  static SupabaseClient get client => Supabase.instance.client;

  /// getter to access the current authenticated user's session
  static Session? get session => client.auth.currentSession;

  /// getter to access the current authenticated user
  static User? get user => client.auth.currentUser;

  /// getter to access the current user's ID
  static String? get currentUserId => client.auth.currentUser?.id;

  /// Sign out the current user
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Sign In with Google
  static Future<bool> signInWithGoogle() async {
    try {
      // For Web, we redirect to the current domain.
      String? redirectUrl;
      if (kIsWeb) { 
        redirectUrl = Uri.base.origin; // e.g. http://localhost:1234
      } else {
        // For Mobile (Android/iOS), use the deep link scheme configured in AndroidManifest.xml/Info.plist
        redirectUrl = 'io.supabase.facebookclone://login-callback';
      }

      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
