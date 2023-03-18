import 'dart:convert';

import 'package:badges/badges.dart';
import '../services/auth.dart';
import '../services/mqtt.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/routes.dart';
import '../providers/cart_provider.dart';
import '../widgets/all_widgets.dart';
// import '../services/socket.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as devtools;
import 'package:http/http.dart' as http;

class CartShellPage extends ConsumerWidget {
  const CartShellPage({required this.child, Key? key}) : super(key: key);
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final auth = ref.watch(authProvider);
    final mqtt = ref.watch(mqttProvider);

    // publush any Listened changes in the cartProvider
    mqtt.publish(cart.state.stateString);

    return WillPopScope(
      onWillPop: () async {
        final shouldDisconnect = showCustomBoolDialog(
          context,
          "Disconnect Cart",
          "Are you Sure you want to disconnect this cart?",
          "Confirm",
        );
        if (await shouldDisconnect) {
          try {
            http.Response res = await auth.postAuthReq(
              '/api/v1/cart/disconnect',
            );
            devtools.log("code: ${res.statusCode}");
            if (res.statusCode == 200) {
              devtools.log("code: ${res.body}");
              context.goNamed(connectRoute);
            }
          } catch (e) {
            devtools.log("$e");
          }
        }
        return false;
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60), //height of appbar
          child: AppBar(
            centerTitle: true,
            backgroundColor: Theme.of(context).backgroundColor,
            // title: Text('Cart ${cart.getCartState()} Mode',
            title: Text('Cart id# ${cart.id}',
                style: const TextStyle(fontSize: 20)),
            actions: [
              Badge(
                badgeContent: Text(
                  cart.getCounter().toString(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                position: const BadgePosition(start: 30, bottom: 30),
                child: Container(
                  margin: const EdgeInsets.only(top: 5, right: 5),
                  alignment: Alignment.topRight,
                  child: const CartMenuWidget(),
                ),
              ),
            ],
          ),
        ),
        drawer: const MenuBar(),
        body: child,
        bottomNavigationBar: const BottomNavigationWidget(),
      ),
    );
  }
}
