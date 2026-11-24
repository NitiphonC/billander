import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'bills_screen.dart';
import 'design_system.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'widgets/common.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  late final AppState state;
  int _index = 0;

  static const _destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.speed_outlined), selectedIcon: Icon(Icons.speed), label: 'ภาพรวม'),
    NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'ปฏิทิน'),
    NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'บิล'),
    NavigationDestination(icon: Icon(Icons.history), label: 'ประวัติ'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'ตั้งค่า'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state = AppState();
    state.load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      state.checkDayChange();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        if (state.dayRollover) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            state.acknowledgeDayRollover();
            showMessage(context, 'วันใหม่แล้ว ระบบคำนวณยอดที่ต้องเก็บใหม่แล้ว');
          });
        }

        // ป้องกัน ListTile/SwitchListTile ทุกตัวตกไปใช้ bodyLarge 16px
        // ของ Material ซึ่งใหญ่กว่าคำอธิบาย AppType.caption 12px
        return ListTileTheme(
          data: ListTileThemeData(
            titleTextStyle: AppType.rowTitle(context),
            subtitleTextStyle: AppType.muted(context),
          ),
          child: Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              DashboardScreen(state: state),
              CalendarScreen(state: state),
              BillsScreen(state: state),
              HistoryScreen(state: state),
              SettingsScreen(state: state),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            destinations: _destinations,
            onDestinationSelected: (index) => setState(() => _index = index),
          ),
          ),
        );
      },
    );
  }
}
