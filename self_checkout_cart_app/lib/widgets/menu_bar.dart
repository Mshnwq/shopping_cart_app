import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/routes.dart';
import '../theme/theme_controller.dart';
import '../providers/mqtt_provider.dart';
import '../providers/auth_provider.dart';
import 'alert_dialogs.dart';
import 'dart:developer' as devtools;

class MenuBar extends ConsumerWidget {
  const MenuBar({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeModeProvider);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).backgroundColor,
              ),
              child: Text(
                'Side menu',
                style: Theme.of(context).textTheme.titleLarge,
              )
              // image: DecorationImage(
              // fit: BoxFit.fill,
              // image: AssetImage('assets/images/cover.jpg'))),
              ),
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('Welcome'),
            onTap: () => {},
          ),
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: const Text('Profile'),
            onTap: () => {Navigator.of(context).pop()},
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onLongPress: () => {},
            onTap: () => {},
          ),
          ListTile(
            leading: const Icon(Icons.border_color),
            title: const Text('Feedback'),
            onTap: () => {Navigator.of(context).pop()},
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Logout'),
            onTap: () async {
              final shouldLogout = await showLogOutDialog(context);
              if (shouldLogout) {
                ref.read(mqttProvider).disconnect();
                // Auth().signOut();
                context.goNamed(logoRoute);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.chrome_reader_mode),
            title: const Text('About'),
            onTap: () => {showAboutDialog(context: context)},
          ),
          ListTile(
            leading: const Icon(Icons.question_mark),
            title: const Text('FAQ\'s'),
            onTap: () => {showAboutDialog(context: context)},
          ),
          IconButton(
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  theme == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
            },
            icon: Icon(
                theme == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
    );
  }
}
