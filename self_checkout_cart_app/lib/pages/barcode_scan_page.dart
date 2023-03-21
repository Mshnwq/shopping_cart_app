import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/all_widgets.dart';
import '../providers/mqtt_provider.dart';
import '../providers/auth_provider.dart';

import 'package:http/http.dart' as http;
import '../models/item_model.dart';
import '../providers/cart_provider.dart';
import '../constants/routes.dart';
import 'dart:developer' as devtools;

// Barcode scanner imports
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/qrcode_scanner.dart';
// import 'package:image_picker/image_picker.dart';
// import '../services/connectivity_service.dart';

class BarcodeScannerPage extends ConsumerWidget {
  BarcodeScannerPage({Key? key}) : super(key: key);

  ScannerController scannerController = ScannerController();

  bool _canScan = true;
  bool _awaitMqtt = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final auth = ref.watch(authProvider);
    final mqtt = ref.watch(mqttProvider);
    final completer = Completer<String>();
    // StreamSubscription subscription;

    // return StreamBuilder<String>(
    // stream: mqtt.onMessage,
    // builder: (context, snapshot) {

    return WillPopScope(
      onWillPop: () async {
        cart.setCartState("active");
        return true;
      },
      child: Scaffold(
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
        ),
        body: Stack(
          alignment: Alignment.center,
          children: [
            MobileScanner(
              allowDuplicates: true,
              controller: scannerController.cameraController,
              onDetect: (image, args) async {
                if (!_canScan) return;
                _canScan = false;
                String? barCode = image.rawValue;
                devtools.log(barCode.toString());
                if (barCode == "" || barCode == null) {
                  return;
                } else {
                  final addToCart = await showCustomBoolDialog(
                    context,
                    "Place item on scale",
                    barCode.toString(),
                    "Add it",
                  );
                  if (addToCart) {
                    // build publish body
                    var publishBody = <String, dynamic>{
                      'mqtt_type': 'request_add_item',
                      'sender': mqtt.clientId,
                      'item_barcode': '123123',
                      // 'item_barcode': barCode.toString(),
                      'timestamp': DateTime.now().millisecondsSinceEpoch
                    };
                    try {
                      _awaitMqtt = true;
                      // Publish the message
                      mqtt.publish(json.encode(publishBody));
                      // Wait for the response message
                      devtools.log("subscribing");
                      StreamSubscription subscription =
                          mqtt.onMessage.listen((message) {
                        completer.complete(message);
                        _awaitMqtt = false;
                        devtools.log("waiting done");
                      });
                      devtools.log("waiting");
                      // Wait for the completer to complete
                      final mqttResponse = json.decode(await completer.future);
                      // Handle the message as desired
                      subscription.cancel();
                      devtools.log("waiting done");
                      _awaitMqtt = false;
                      // devtools.log("RESPONSE: $mqttResponse");
                      if (mqttResponse['status'] == 'success') {
                        devtools.log("HERE_11");
                        // http.Response httpRes = await auth.postAuthReq(
                        //   '/api/v1/item/add',
                        //   body: <String, dynamic>{
                        //     'barcode': barCode.toString()
                        //   },
                        // );
                        // devtools.log("code: ${httpRes.statusCode}");
                        // if success, add item to cart and exit refresh page
                        // if (httpRes.statusCode == 200) {
                        if (true) {
                          var product = mqttResponse['product'];
                          devtools.log("$product");
                          Item item = Item(
                              name: product['en_name'],
                              unit: 'Kg',
                              price: product['price'],
                              image:
                                  'https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg');
                          // image: product['img_link']);

                          cart.addItem(item);
                          cart.setCartState("active");
                          context.goNamed(cartRoute);
                        }
                      } else if (mqttResponse['status'] == 'scale_fail') {
                        bool isRetry = await showCustomBoolDialog(
                            context,
                            "Failed to add item",
                            "Make sure item is placed correctly on scale",
                            "Retry");
                        if (isRetry) {
                          _canScan = true;
                        } else {
                          cart.setCartState("active");
                          GoRouter.of(context).pop();
                        }
                      } else if (mqttResponse['status'] == 'item_not_found') {
                        devtools.log("HERE_4");
                        bool isRetry = await showCustomBoolDialog(
                          context,
                          "Item Not Found",
                          "This item is not in our database try your luck with another item",
                          "Ok",
                        );
                        if (isRetry) {
                          cart.setCartState("active");
                          context.goNamed(cartRoute);
                        } else {
                          cart.setCartState("active");
                          context.goNamed(cartRoute);
                        }
                      } else {
                        bool isRetry = await showCustomBoolDialog(
                          context,
                          "ERROR",
                          "Unexpexted error has occured",
                          "Ok",
                        );
                        if (isRetry) {
                          cart.setCartState("active");
                          context.goNamed(cartRoute);
                        } else {
                          cart.setCartState("active");
                          context.goNamed(cartRoute);
                        }
                      }
                    } catch (e) {
                      devtools.log("$e");
                      bool isRetry = await showCustomBoolDialog(
                        context,
                        "Server error",
                        "$e",
                        "Retry",
                      );
                      if (isRetry) {
                        _canScan = true;
                      } else {
                        cart.setCartState("active");
                        GoRouter.of(context).pop();
                      }
                    }
                  } else {
                    cart.setCartState("active");
                    GoRouter.of(context).pop();
                  }
                }
              },
            ),
            Positioned(
              top: 100,
              child: Container(
                decoration: BoxDecoration(
                    color: const Color.fromARGB(85, 94, 238, 101),
                    borderRadius: BorderRadius.circular(20)),
                width: 300,
                height: 40,
                child: const Center(
                  child: Text(
                    "Scan an prodcut barcode",
                    style: TextStyle(),
                  ),
                ),
              ),
            ),
            Visibility(
              visible: _awaitMqtt,
              child: Container(
                color: Colors.white.withOpacity(0.8),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
