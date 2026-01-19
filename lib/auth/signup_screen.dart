import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signUp() async {
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final username = _usernameController.text.trim();

      if (email.isEmpty || password.isEmpty || username.isEmpty) {
        throw AuthException('Please fill in all fields');
      }

      // 1. Sign up with Supabase
      final response = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
        // We pass user_metadata to store the username immediately or handle it in a trigger
        data: {'username': username},
        emailRedirectTo:
            'https://sybcqriolojnamwbdjsm.supabase.co/auth/v1/callback',
      );

      // 2. Profile creation is handled by the Supabase Trigger 'on_auth_user_created'.
      // We don't need to manually insert into 'profiles' anymore.

      if (mounted) {
        Navigator.pop(
            context); // Go back to login or let the auth state listener handle navigation
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account Created! Please Log In.')));
      }
    } on AuthException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                  labelText: 'Username', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Sign Up',
                        style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),

            // Google Sign In
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        await SupabaseService.signInWithGoogle();
                        if (mounted) setState(() => _isLoading = false);
                      },
                icon: const Icon(Icons.login, color: Colors.red),
                label: const Text('Continue with Google',
                    style: TextStyle(color: Colors.black)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
