/// App Configuration
/// Contains API endpoints and credentials
class AppConfig {
  // Backend WebSocket URL
  static const String websocketUrl = 'ws://192.168.1.40:8000/ws/recite';
  // static const String websocketUrl = 'wss://backend.mangkidals.my.id/ws/recite';
  
  // For network/real device, use your computer's IP:
  // static const String websocketUrl = 'ws://192.168.1.XXX:8000/ws/recite';
  
  // Supabase Configuration
  static const String supabaseUrl = 'https://xqguweftjklmzmrwtqet.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhxZ3V3ZWZ0amtsbXptcnd0cWV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzNzYxNjgsImV4cCI6MjA2OTk1MjE2OH0.JckKnoCcns114jhSUfycEmrnUWiUTySR2P0xfzBhkDU';
}
