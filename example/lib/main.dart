import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:office_core/office_core.dart';

import 'screens/home_screen.dart';
import 'screens/ads_screen.dart';
import 'screens/trial_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/config_screen.dart';

/// Shared app state (premium toggle) accessible from all screens.
final ValueNotifier<bool> premiumNotifier = ValueNotifier<bool>(false);

/// Premium provider backed by [premiumNotifier]. Uses the built-in
/// [ValueNotifierPremiumProvider] adapter from office_core.
late final ValueNotifierPremiumProvider examplePremiumProvider =
    ValueNotifierPremiumProvider(premiumNotifier);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In a real app, initialize Firebase here:
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // await MobileAds.instance.initialize();

  // In a real app, OfficeCore.initialize() would be called here:
  // await OfficeCore.initialize(OfficeCoreConfig(
  //   premiumProvider: examplePremiumProvider,
  //   notificationBackend: NotificationBackendConfig(
  //     openedApiUrl: 'https://api.example.com/notification/opened',
  //     deviceRegistryPath: 'devices',
  //     topics: ['all_users'],
  //   ),
  // ));

  runApp(const OfficeCoreExampleApp());
}

class OfficeCoreExampleApp extends StatelessWidget {
  const OfficeCoreExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OfficeCore Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    AdsScreen(),
    TrialScreen(),
    NotificationsScreen(),
    ConfigScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.ad_units_outlined),
              selectedIcon: Icon(Icons.ad_units),
              label: 'Ads'),
          NavigationDestination(
              icon: Icon(Icons.lock_outline),
              selectedIcon: Icon(Icons.lock_open),
              label: 'Trial'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: 'Push'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Config'),
        ],
      ),
    );
  }
}
