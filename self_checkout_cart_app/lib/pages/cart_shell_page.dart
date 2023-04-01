import 'dart:convert';

import 'package:badges/badges.dart' as badge;
import '../providers/mqtt_provider.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/routes.dart';
import '../providers/cart_provider.dart';
import 'package:self_checkout_cart_app/widgets/menu_bar.dart' as menuBar;
import 'package:self_checkout_cart_app/widgets/all_widgets.dart';
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
    var publishBody = <String, dynamic>{
      'mqtt_type': 'update_mode',
      'sender': mqtt.clientId,
      'mode': cart.state.stateString,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    };
    mqtt.publish(json.encode(publishBody));

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
            if (res.statusCode == 200) {
              mqtt.disconnect();
              context.goNamed(connectRoute);
            }
          } catch (e) {
            devtools.log("$e");
          }
        }
        return false;
      },
      child: StreamBuilder<String>(
        stream: mqtt.onAlarmMessage,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // handle loading
            if (json.decode(snapshot.data!)['trigger']) {
              devtools
                  .log('AWAITING ADMINISTRATOR ${snapshot.data.toString()}');
              return const Text('AWAITING ADMINISTRATOR');
            } else {
              return cartShell(context, ref);
            }
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            // handle data
            return cartShell(context, ref);
          } else if (snapshot.hasError) {
            // handle error (note: snapshot.error has type [Object?])
            final error = snapshot.error!;
            return Text(error.toString());
          } else {
            // uh, oh, what goes here?
            return const Text('Some error occurred - welp!');
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
        child: AppBar(
          centerTitle: true,
          backgroundColor: Theme.of(context).backgroundColor,
          // title: Text('Cart ${cart.getCartState()} Mode',
          title: Text('Cart id# ${cart.id}, ${cart.state.stateString}',
              style: const TextStyle(fontSize: 20)),
          actions: [
            badge.Badge(
              badgeContent: Text(
                cart.getCounter().toString(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              position: const badge.BadgePosition(start: 30, bottom: 30),
              child: Container(
                margin: const EdgeInsets.only(top: 5, right: 5),
                alignment: Alignment.topRight,
                child: const CartMenuWidget(),
              ),
            ),
          ],
        ),
      ),
      drawer: const menuBar.MenuBar(),
      body: child,
      bottomNavigationBar: const BottomNavigationWidget(),
    );
  }
}
