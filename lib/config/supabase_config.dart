/// Supabase Configuration
/// Store your Supabase credentials here

class SupabaseConfig {
  // TODO: Replace with your actual Supabase credentials
  static const String supabaseUrl = 'https://yfosfxhwxikgqpjdtvlo.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlmb3NmeGh3eGlrZ3FwamR0dmxvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIzMzcyNTYsImV4cCI6MjA3NzkxMzI1Nn0.YkLJL4GlbmXBXP0zkKbaXKgEfqzbL_ioRFx6IGfUauI';

  // Backend API Configuration
  // IMPORTANT: Replace with your computer's actual IP address
  // Run 'ipconfig' in CMD to find your IPv4 Address
  // Example: 'http://192.168.1.100:5000'
  static const String backendUrl =
      // 'http://192.168.1.15:5000'; // Dann Router IP
      'http://10.0.0.35:5000'; // Home router IP
  // 'http://10.88.12.56:5000'; // Phone IP

  // API Endpoints
  static const String classifyEndpoint = '/api/classify';
  static const String documentsEndpoint = '/api/documents';
  static const String statsEndpoint = '/api/stats';
}
