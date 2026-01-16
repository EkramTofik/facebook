import 'package:flutter/material.dart';

/// AppConstants holds all the global configuration for the app.
/// This makes it easy to change colors or keys in one place.
class AppConstants {
  // ===========================================================================
  // 1. App Colors (Facebook Style)
  // ===========================================================================
  
  // The main blue color used by Facebook
  static const Color primaryColor = Color(0xFF1877F2);
  
  // Light gray background color for the feed
  static const Color scaffoldBackgroundColor = Color(0xFFF0F2F5);
  
  // White color for cards and backgrounds
  static const Color cardColor = Colors.white;
  
  // Text colors
  static const Color primaryText = Colors.black; // Main black text
  static const Color secondaryText = Color(0xFF65676B); // Gray text for subtitles

  // ===========================================================================
  // 2. Layout Constants
  // ===========================================================================
  
  // Standard padding used across the app (16.0 pixels)
  static const double defaultPadding = 16.0;
  
  // Rounded corners for cards and buttons
  static const double defaultRadius = 8.0;

  // ===========================================================================
  // 3. Supabase Configuration
  // ===========================================================================
  
  // TODO: REQUIRED - Replace these with your actual Supabase project details.
  // Go to Supabase Dashboard -> Settings -> API to find these.
  static const String supabaseUrl = 'https://sybcqriolojnamwbdjsm.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN5YmNxcmlvbG9qbmFtd2JkanNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg1NzEwODIsImV4cCI6MjA4NDE0NzA4Mn0.xhkkpHAtcWADSUSw4XEzeDRceLjElPTUBjarNfYroQo';
}
