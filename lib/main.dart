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
import 'screens/admin/officer_management.dart';
import 'screens/authority/authority_home.dart';
import 'screens/authority/resolve_screen.dart';
import 'screens/officer/officer_home.dart';
import 'screens/shared/notification_screen.dart';

import 'widgets/role_guard.dart';

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
        title: 'CiviSense AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: '/',
        routes: {
          '/': (ctx) => const SplashScreen(),
          '/login': (ctx) => const LoginScreen(),
          '/register': (ctx) => const RegisterScreen(),
          '/citizen': (ctx) => RoleGuard(allowedRoles: ['citizen'], child: CitizenHome()),
          '/citizen/submit': (ctx) => RoleGuard(allowedRoles: ['citizen'], child: SubmitReportScreen()),
          '/citizen/reports': (ctx) => RoleGuard(allowedRoles: ['citizen'], child: MyReportsScreen()),
          '/admin': (ctx) => RoleGuard(allowedRoles: ['admin'], child: AdminHome()),
          '/admin/reports': (ctx) => RoleGuard(allowedRoles: ['admin'], child: AllReportsScreen()),
          '/admin/analytics': (ctx) => RoleGuard(allowedRoles: ['admin'], child: AnalyticsScreen()),
          '/admin/officers': (ctx) => RoleGuard(allowedRoles: ['admin'], child: OfficerManagementScreen()),
          '/authority': (ctx) => RoleGuard(allowedRoles: ['authority'], child: AuthorityHome()),
          '/authority/resolve': (ctx) => RoleGuard(allowedRoles: ['authority'], child: ResolveScreen()),
          '/officer': (ctx) => RoleGuard(allowedRoles: ['officer'], child: OfficerHome()),
          '/notifications': (ctx) => RoleGuard(allowedRoles: ['citizen', 'admin', 'authority', 'officer'], child: NotificationScreen()),
        },
      ),
    );
  }
}
