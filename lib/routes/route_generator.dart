import 'package:flutter/material.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/role_gate_screen.dart';
import '../features/customer/requests/my_requests_screen.dart';
import '../features/customer/requests/part_request_screen.dart';
import '../features/customer/search/search_screen.dart';
import '../features/customer/vehicle/vehicle_details_screen.dart';
import '../features/finance/invoice_details_screen.dart';
import '../features/finance/payment_checkout_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/worker/requests/worker_requests_screen.dart';
import '../features/worker/vehicles/add_vehicle_screen.dart';
import '../features/worker/vehicles/my_vehicles_screen.dart';
import '../routes/app_routes.dart';
import '../shared/layout/admin_shell.dart';
import '../shared/layout/customer_shell.dart';
import '../shared/layout/worker_shell.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case AppRoutes.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case AppRoutes.otp:
        return MaterialPageRoute(builder: (_) => const OtpScreen());
      case AppRoutes.roleGate:
        return MaterialPageRoute(builder: (_) => const RoleGateScreen());
      case AppRoutes.customerShell:
        return MaterialPageRoute(builder: (_) => const CustomerShell());
      case AppRoutes.search:
        return MaterialPageRoute(builder: (_) => const SearchScreen());
      case AppRoutes.vehicleDetails:
        return MaterialPageRoute(builder: (_) => const VehicleDetailsScreen());
      case AppRoutes.partRequest:
        return MaterialPageRoute(builder: (_) => const PartRequestScreen());
      case AppRoutes.myRequests:
        return MaterialPageRoute(builder: (_) => const MyRequestsScreen());
      case AppRoutes.invoiceDetails:
        final invoiceId = (settings.arguments ?? '').toString();
        return MaterialPageRoute(
          builder: (_) => InvoiceDetailsScreen(invoiceId: invoiceId),
        );
      case AppRoutes.paymentCheckout:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => PaymentCheckoutScreen(
            url: (args['url'] ?? '').toString(),
            title: (args['title'] ?? 'Payment').toString(),
          ),
        );
      case AppRoutes.workerShell:
        return MaterialPageRoute(builder: (_) => const WorkerShell());
      case AppRoutes.addVehicle:
        return MaterialPageRoute(builder: (_) => const AddVehicleScreen());
      case AppRoutes.myVehicles:
        return MaterialPageRoute(builder: (_) => const MyVehiclesScreen());
      case AppRoutes.workerRequests:
        return MaterialPageRoute(builder: (_) => const WorkerRequestsScreen());
      case AppRoutes.adminShell:
        return MaterialPageRoute(builder: (_) => const AdminShell());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }
}