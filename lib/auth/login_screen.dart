import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Function to handle login
  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw AuthException('Please fill in all fields');
      }

      // Supabase Login
      await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      // On success, the main wrapper will redirect us (Auth State Change)
    } on AuthException catch (e) {
      if (mounted) {
        String message = e.message;
        if (message.contains('Email not confirmed')) {
          message = 'Please check your email and click the confirmation link.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unexpected error occurred')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo or Icon
              const Icon(Icons.facebook, size: 80, color: AppConstants.primaryColor),
              const SizedBox(height: 20),
              
              // Email Field
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),

              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Log In', style: TextStyle(color: Colors.white, fontSize: 16)),
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
                  label: const Text('Continue with Google', style: TextStyle(color: Colors.black)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Sign Up Link
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                },
                child: const Text('Create New Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
