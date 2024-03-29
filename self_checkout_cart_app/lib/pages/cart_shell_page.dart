import 'dart:async';
import 'dart:convert';

import 'package:badges/badges.dart' as badge;
import '../providers/mqtt_provider.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/routes.dart';
import '../providers/cart_provider.dart';
import 'package:self_checkout_cart_app/widgets/menu_bar.dart' as menu_bar;
import 'package:self_checkout_cart_app/widgets/all_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as devtools;
import 'package:http/http.dart' as http;
import '../route/endpoint_navigate.dart';

class CartShellPage extends ConsumerWidget {
  CartShellPage({required this.child, Key? key}) : super(key: key);
  final Widget child;
  bool isDrawerOpen = false; // Track the state of the drawer

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final auth = ref.watch(authProvider);
    final mqtt = ref.watch(mqttProvider);

    // publush any Listened changes in the cartProvider
    var publishBody = <String, dynamic>{
      'mqtt_type': 'request_update_status',
      'sender': mqtt.clientId,
      'status': cart.state.stateString,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    };
    mqtt.publish(json.encode(publishBody));

    return WillPopScope(
      onWillPop: () async {
        if (isDrawerOpen) {
          context.pop();
        } else {
          final shouldDisconnect = await customDialog(
            context: context,
            title: 'Disconnect Cart?',
            message: 'Are you Sure you want to disconnect this cart?',
            buttons: const [
              ButtonArgs(
                text: 'Disconnect',
                value: true,
              ),
              ButtonArgs(
                text: 'Cancel',
                value: false,
              ),
            ],
          );
          if (shouldDisconnect) {
            await EndpointAndNavigate(
              context,
              () => auth.postAuthReq('/api/v1/cart/disconnect'),
              (context) => context.goNamed(connectRoute),
              "Failed to disconnect cart",
              timeoutDuration: 3,
            );
          }
        }
        return false;
      },
      child: StreamBuilder<String>(
        stream: mqtt.onAlarmMessage,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            devtools.log('AWAITING ${snapshot.data.toString()}');
            // handle loading
            if (jsonDecode(snapshot.data!)['status'].toString() == '5') {
              devtools
                  .log('AWAITING ADMINISTRATOR ${snapshot.data.toString()}');
              // context.pop();
              return alarm(context, snapshot.hasData.toString());
            } else {
              return cartShell(context, ref);
            }
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            // handle data
            return cartShell(context, ref);
          } else if (snapshot.hasError) {
            // handle error (note: snapshot.error has type [Object?])
            final error = snapshot.error!;
            return alarm(context, error.toString());
          } else {
            // uh, oh, what goes here?
            return error(context);
            return cartShell(context, ref);
          }
        },
      ),
    );
  }

  Widget cartShell(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60), //height of appbar
        child: Builder(
          builder: (BuildContext context) {
            return AppBar(
              centerTitle: true,
              backgroundColor: Theme.of(context).colorScheme.primary,
              // title: Text('Cart ${cart.getCartState()} Mode',
              title: Text(
                'Cart id# ${cart.id}, ${cart.state.stateString}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.background,
                    ),
              ),
              leading: IconButton(
                icon: Icon(
                  Icons.menu,
                  color: Theme.of(context).colorScheme.background,
                ),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
              actions: [
                badge.Badge(
                  badgeContent: Text(
                    cart.getCounter().toString(),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.background,
                        fontWeight: FontWeight.bold),
                  ),
                  position: const badge.BadgePosition(start: 30, bottom: 30),
                  child: Container(
                    margin: const EdgeInsets.only(top: 5, right: 5),
                    alignment: Alignment.topRight,
                    child: const CartMenuWidget(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      drawer: const menu_bar.MenuBar(),
      onDrawerChanged: (isOpened) {
        isDrawerOpen = isOpened;
      },
      body: !cart.isOnline() ? cartOffline(context) : child,
      bottomNavigationBar: const BottomNavigationWidget(),
    );
  }

  Widget cartOffline(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Image.asset('assets/images/disconnected.png'),
          const SizedBox(height: 20),
          Text(
            'Cart is Disconnected',
            style: Theme.of(context).textTheme.subtitle1,
          ),
        ],
      ),
    );
  }

  Widget error(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Image.asset('assets/images/disconnected.png'),
            const SizedBox(height: 20),
            Text(
              'Some error occurred - welp!',
              style: Theme.of(context).textTheme.subtitle1,
            ),
          ],
        ),
      ),
    );
  }

  Widget alarm(BuildContext context, String message) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Image.asset('assets/images/lock.png'),
            const SizedBox(height: 20),
            Text(
              'AWAITING ADMINISTRATOR',
              style: Theme.of(context).textTheme.subtitle1,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: Theme.of(context).textTheme.subtitle1,
            ),
          ],
        ),
      ),
    );
  }
}
