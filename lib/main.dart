import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'features/dashboard/dashboard_screen.dart';
import 'core/services/settings_service.dart';
import 'features/manga/manga_reader_screen.dart';
import 'features/units/units_screen.dart';
import 'features/decks/decks_screen.dart';
import 'features/profile/profile_screen.dart';
import 'core/i18n/app_strings.dart';
import 'core/providers/fullscreen_provider.dart';

final rootTabIndexProvider = StateProvider<int>((ref) => 0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  runApp(const ProviderScope(child: NexusLinguaApp()));
}

class NexusLinguaApp extends ConsumerWidget {
  const NexusLinguaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    
    ThemeMode mode;
    switch (settings.themeModeIndex) {
      case 1: mode = ThemeMode.light; break;
      case 2: mode = ThemeMode.dark; break;
      default: mode = ThemeMode.system; break;
    }

    final Color seedColor = Color(settings.themeColorValue);

    return MaterialApp(
      title: 'Kotoba Trail',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: mode,
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> with WidgetsBindingObserver {
  bool _isBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isBackgrounded = state == AppLifecycleState.inactive || state == AppLifecycleState.paused;
    });
  }

  final List<Widget> _screens = const [
    DashboardScreen(),
    MangaReaderScreen(),
    UnitsScreen(),
    DecksScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(rootTabIndexProvider);
    final isFullscreen = ref.watch(fullscreenProvider);
    final settings = ref.watch(settingsProvider);
    final s = AppStrings(settings.motherTongue);
    
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: isFullscreen ? null : NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(rootTabIndexProvider.notifier).state = index;
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: s.dashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.book_outlined),
            selectedIcon: const Icon(Icons.book),
            label: s.navManga,
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school),
            label: s.navPath,
          ),
          NavigationDestination(
            icon: const Icon(Icons.style_outlined),
            selectedIcon: const Icon(Icons.style),
            label: s.navDecks,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: s.navSettings,
          ),
        ],
      ),
    );
  }
}

