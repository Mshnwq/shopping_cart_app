import 'dart:convert';
import 'dart:io';
import 'dart:developer' as devtools show log;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '/services/secure.dart';
import '../widgets/all_widgets.dart';
import '../services/env.dart' as env;

final authProvider = ChangeNotifierProvider.autoDispose((ref) => Auth());

class Auth with ChangeNotifier {
  // FirebaseAuth auth = FirebaseAuth.instance;

  // Only changeable variable to optimize rebuild, when [_isLoggedIn] change
  // the entire app will rebuild to control user authorization
  bool _isLoggedIn = false;

  final String _loginRoute = '/api/v1/mobile/token';
  final String _registerRoute = '/api/v1/mobile/register';
  final String _refreshRoute = "/api/v1/mobile/refresh";
  final String ping = '/ping';
  late String cart_id = 'test';
  late String username = 'test';

  void setCartId(String id) => {cart_id = id};

  final SecureStorage _secureStorage = SecureStorage();
  SecureStorage get secureStorage => _secureStorage;

  Future<bool> login(BuildContext context, String email, String pass) async {
    var httpBody = <String, String>{
      'username': email,
      'password': pass,
    };
    try {
      http.Response res = await loginReq(_loginRoute, body: httpBody);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        // showAlertMassage(context, res.statusCode.toString());
        // username = body['user']['username'];
        // user_id = body['user']['id'].toString();
        String? authType = body[env.tokenType];
        _secureStorage.setAccessToken("$authType ${body[env.accessToken]}");
        _secureStorage
            .setRefreshToken("$authType ${body[env.refreshToken]}"); // TODO 401
        _isLoggedIn = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      showAlertMassage(context, "$e");
      throw Exception(e); // TODO: Implement internet error
      // return false;
      // } finally {
      // showAlertMassage(context, "$e");
    }
  }

  /// using [http]
  Future<bool> register(
      BuildContext context, String username, String email, String pass) async {
    var body = <String, String>{
      'username': username,
      "full_name": "string",
      'email': email,
      "role": '0',
      "phone_num": "966501386297",
      'hashed_password': pass,
      "birthdate": "2000-03-02"
    };
    try {
      http.Response res = await postReq(_registerRoute, body: body);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        // showAlertMassage(context, res.statusCode.toString());
        String? authType = body[env.tokenType];
        _secureStorage.setAccessToken("$authType ${body[env.accessToken]}");
        _secureStorage.setRefreshToken("$authType ${body[env.refreshToken]}");
        // _isLoggedIn = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      showAlertMassage(context, "$e");
      throw Exception(e); // TODO: Implement internet error
      // return false;
      // } finally {
      // showAlertMassage(context, "$e");
    }
  }

  String _extractAccessToken(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    String? authType = body[env.tokenType];
    return "$authType ${body[env.accessToken]}";
  }

  Future<String?> _getNewAccessToken() async {
    String? refToken = await _secureStorage.getRefreshToken();
    http.Response res = await getReq(_refreshRoute,
        header: {HttpHeaders.authorizationHeader: refToken});
    if (res.statusCode == 200) {
      return _extractAccessToken(res);
    }
    return null;
  }

  http.Request _repeatRequest(http.Request req) {
    http.Request reReq = http.Request(req.method, req.url);
    reReq.body = req.body;
    reReq.headers.addAll(req.headers);
    return reReq;
  }

  Future<http.Response> checkToken(http.Response res) async {
    if (res.statusCode == 200) {
      return res;
    } else if (res.statusCode == 401) {
      http.Request newReq = _repeatRequest(res.request as http.Request);
      if (_isLoggedIn) {
        String? newAccessToken = await _getNewAccessToken();
        if (newAccessToken != null) {
          await _secureStorage.setAccessToken(newAccessToken);
          newReq.headers[HttpHeaders.authorizationHeader] = newAccessToken;
        } // retry after refresh
        http.StreamedResponse retRes = await newReq.send();
        if (retRes.statusCode == 200) {
          return http.Response.fromStream(retRes);
        }
      }
    } else {
      throw Exception('${res.statusCode.toString()} ${res.body.toString()}');
    }
    // logout(); // TODO
    throw Exception("Session Expired");
    // return null;
  }

  Future<bool> checkIfLoggedIn() async {
    _isLoggedIn = await _secureStorage.containsData(env.accessToken);
    return _isLoggedIn;
  }

  Future<http.Response> loginReq(String route,
      {Map<String, dynamic>? body, Map<String, dynamic>? header}) async {
    return await http.post(
      Uri.http(env.baseURL, route),
      body: body,
    );
  }

  Future<http.Response> postReq(String route,
      {Map<String, dynamic>? body, Map<String, dynamic>? header}) {
    return http.post(
      Uri.http(env.baseURL, route),
      body: jsonEncode(body),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        ...?header
      },
    );
  }

  Future<http.Response> getReq(String route, {Map<String, dynamic>? header}) {
    return http.get(
      Uri.http(env.baseURL, route),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        ...?header
      },
    );
  }

  Future<http.Response> sendEmptyPost(
    String route,
  ) async {
    final uri = Uri.http(env.baseURL, route);
    final headers = {
      'Content-Type': 'application/json',
      "Accept": "application/json",
    };
    Map<String, dynamic> body = {'id': 21, 'name': 'bob'};
    String jsonBody = json.encode(body);
    final encoding = Encoding.getByName('utf-8');
    http.Response response = await http.post(
      uri,
      headers: headers,
      body: jsonBody,
      encoding: encoding,
    );
    return response;
  }

  Future<http.Response> postAuthReq(String route,
      {Map<String, dynamic>? body, Map<String, dynamic>? header}) async {
    String? token = await _secureStorage.getAccessToken();
    Map<String, dynamic> authHeader = {"Authorization": token, ...?header};
    try {
      http.Response res = await postReq(route, body: body, header: authHeader);
      http.Response checkedRes = await checkToken(res);
      return checkedRes;
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<http.Response> getAuthReq(String route,
      {Map<String, dynamic>? header}) async {
    String? token = await _secureStorage.getAccessToken();
    Map<String, dynamic> authHeader = {"Authorization": token, ...?header};
    try {
      http.Response res = await getReq(route, header: authHeader);
      http.Response checkedRes = await checkToken(res);
      return checkedRes;
    } catch (e) {
      throw Exception(e);
    }
  }

  void logout() {
    _secureStorage.clearTokens();
    _isLoggedIn = false;
    notifyListeners();
  }
}
