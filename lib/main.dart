import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/citizen/citizen_home.dart';
import 'screens/citizen/submit_report.dart';
import 'screens/citizen/my_reports.dart';
import 'screens/admin/admin_home.dart';
import 'screens/admin/all_reports.dart';
import 'screens/admin/analytics_screen.dart';
import 'screens/authority/authority_home.dart';
import 'screens/authority/resolve_screen.dart';

void main() {
  runApp(const CivicSafeApp());
}

class CivicSafeApp extends StatelessWidget {
  const CivicSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(apiService),
      child: MaterialApp(
        title: 'CivicSafe',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: '/',
        routes: {
          '/': (ctx) => const SplashScreen(),
          '/login': (ctx) => const LoginScreen(),
          '/register': (ctx) => const RegisterScreen(),
          '/citizen': (ctx) => const CitizenHome(),
          '/citizen/submit': (ctx) => const SubmitReportScreen(),
          '/citizen/reports': (ctx) => const MyReportsScreen(),
          '/admin': (ctx) => const AdminHome(),
          '/admin/reports': (ctx) => const AllReportsScreen(),
          '/admin/analytics': (ctx) => const AnalyticsScreen(),
          '/authority': (ctx) => const AuthorityHome(),
          '/authority/resolve': (ctx) => const ResolveScreen(),
        },
      ),
    );
  }
}
