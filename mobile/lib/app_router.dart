import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'admin_portal.dart';
import 'alerts_screen.dart';
import 'analytics_portal.dart';
import 'citizen_home.dart';
import 'config.dart';
import 'crew_portal.dart';
import 'emergency_portal.dart';
import 'live_map_screen.dart';
import 'login_screen.dart';
import 'my_reports_screen.dart';
import 'officer_portal.dart';
import 'otp_screen.dart';
import 'profile_screen.dart';
import 'report_flow.dart';
import 'settings_screen.dart';
import 'scalable_operations.dart';
import 'store.dart';
import 'support_portal.dart';

/// Canonical route names for the existing Flutter app.
/// Keeping route names in one place prevents disconnected portals and typos.
abstract final class NalaRoutes {
  static const login = '/login';
  static const home = '/home';
  static const otp = '/otp';
  static const report = '/report';
  static const map = '/map';
  static const myReports = '/myreports';
  static const profile = '/profile';
  static const alerts = '/alerts';
  static const officer = '/officer';
  static const crew = '/crew';
  static const admin = '/admin';
  static const analytics = '/analytics';
  static const support = '/support';
  static const emergency = '/emergency';
  static const settings = '/settings';
  static const terms = '/terms';
  static const operations = '/operations';
  static const operationsCatalogue = '/operations/catalogue';
}

class NalaRouter {
  static Route<dynamic>? onGenerateRoute(
    BuildContext context,
    RouteSettings settings,
  ) {
    final name = settings.name ?? NalaRoutes.login;
    final store = context.read<AppStore>();

    switch (name) {
      case '/':
      case NalaRoutes.login:
        return _page(const LoginScreen(), name);
      case NalaRoutes.otp:
        return _page(const OtpScreen(), name);
      case NalaRoutes.home:
        final homeAllowed =
            store.citizenSession != null ||
            (store.portal != Portal.citizen && store.staffSession != null);
        return _page(
          homeAllowed ? const CitizenPortal() : const LoginScreen(),
          homeAllowed ? name : NalaRoutes.login,
        );
      case NalaRoutes.report:
        return _page(const ReportFlowScreen(), name);
      case NalaRoutes.map:
        return _page(const LiveMapScreen(), name);
      case NalaRoutes.myReports:
        return _rolePage(
          context,
          const MyReportsScreen(),
          name,
          allowed:
              store.portal == Portal.citizen && store.citizenSession != null,
        );
      case NalaRoutes.profile:
        return _page(const ProfileScreen(), name);
      case NalaRoutes.alerts:
        return _page(const AlertsScreen(), name);
      case NalaRoutes.officer:
        return _rolePage(
          context,
          const OfficerPortal(),
          name,
          allowed: store.portal == Portal.officer && store.staffSession != null,
        );
      case NalaRoutes.crew:
        return _rolePage(
          context,
          const CrewPortal(),
          name,
          allowed: store.portal == Portal.crew && store.staffSession != null,
        );
      case NalaRoutes.admin:
        return _rolePage(
          context,
          const AdminDashboard(),
          name,
          allowed: store.portal == Portal.admin && store.isAuthenticated,
        );
      case NalaRoutes.analytics:
        return _page(const AnalyticsPortal(), name);
      case NalaRoutes.support:
        return _page(const SupportPortal(), name);
      case NalaRoutes.emergency:
        return _page(const EmergencyPortal(), name);
      case NalaRoutes.settings:
        return _page(const SettingsScreen(), name);
      case NalaRoutes.terms:
        return _page(const TermsPrivacyScreen(), name);
      case NalaRoutes.operations:
        return _rolePage(
          context,
          const ScalableOperationsScreen(),
          name,
          allowed: store.portal != Portal.citizen && store.isAuthenticated,
        );
      case NalaRoutes.operationsCatalogue:
        return _rolePage(
          context,
          const ScalableCatalogueScreen(),
          name,
          allowed: store.portal != Portal.citizen && store.isAuthenticated,
        );
      default:
        return _page(const LoginScreen(), NalaRoutes.login);
    }
  }

  static Route<dynamic> _rolePage(
    BuildContext context,
    Widget page,
    String name, {
    required bool allowed,
  }) {
    return _page(
      allowed ? page : const LoginScreen(),
      allowed ? name : NalaRoutes.login,
    );
  }

  static MaterialPageRoute<dynamic> _page(Widget page, String name) {
    return MaterialPageRoute(
      settings: RouteSettings(name: name),
      builder: (_) => page,
    );
  }
}
