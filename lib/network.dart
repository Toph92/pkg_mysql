import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pkg_utils/pkg_utils.dart';
import 'package:pkg_utils/extensions.dart';
import 'dart:async';
//import 'package:collection/collection.dart';

class NetworkParams {
  String baseUrl = "https://xxxx/api/v1/";

  NetworkParams() {
    assert(baseUrl.right(1) == '/');
  }
}

class Token {
  String accessToken;
  //int session;
  String tokenType;
  int expireTimeout;
  DateTime? expireDatetime;

  Token(
      {required this.accessToken,
      //required this.session,
      required this.tokenType,
      required this.expireTimeout}) {
    expireDatetime = DateTime.now().add(Duration(seconds: expireTimeout - 60));
  }

  factory Token.fromJson(Map<String, dynamic> jsonMap) {
    return Token(
      accessToken: jsonMap["access_token"],
      //session: jsonMap["session"],
      tokenType: jsonMap["token_type"],
      expireTimeout: jsonMap["expires_in"],
    );
  }
  String authHeader() => "Bearer $accessToken";

  bool isExpired() {
    DateTime now = DateTime.now();
    if (expireDatetime != null &&
        now.millisecondsSinceEpoch < expireDatetime!.millisecondsSinceEpoch) {
      return false;
    } else {
      return true;
    }
  }
}

enum HttpMethod { post, get }

enum NetworkStatus { ok, timeout, otherError }

mixin NetDatasource {
  bool connected = false;

  Future<(String? response, NetworkStatus code)> loadDataFromSourceAsync(
      {required HttpMethod method,
      Map<String, dynamic>? jsonBody,
      Map<String, String>? jsonBodyFields,
      Map<String, String>? jsonHeaders,
      required String url}) async {
    assert(url.left(1) != '/');

    var defaultHeaders = {'Content-Type': 'application/x-www-form-urlencoded'};
    if (jsonHeaders != null) {
      defaultHeaders.addAll(jsonHeaders);
    }
    try {
      var request = http.Request(method == HttpMethod.post ? 'POST' : 'GET',
          Uri.parse('${NetworkParams().baseUrl}$url'));
      if (jsonBody != null) {
        request.body = jsonEncode(jsonBody);
      }
      if (jsonBodyFields != null) {
        request.bodyFields = jsonBodyFields;
      }
      request.headers.addAll(defaultHeaders);
      http.StreamedResponse response = await request.send();
      connected = true;
      if (response.statusCode == 200) {
        return (await response.stream.bytesToString(), NetworkStatus.ok);
      } else {
        Console.printColor(PrintColor.red, response.reasonPhrase);
      }
      return (null, NetworkStatus.otherError);
    } catch (e) {
      connected = false;
      Console.printColor(PrintColor.red, "Network timeout ?");
      return (null, NetworkStatus.timeout);
    }
  }
}
/*
class ApiServer with NetDatasource {
  Token? token;
  bool inProgress = false;

  List<DbRecord> outputQueue = [];

  // add json map to queue
  void queueAdd(DbRecord item) {
    if (outputQueue.contains(item) == true) return;
    Console.printColor(PrintColor.grey, "add 2 queue $item");
    outputQueue.add(item);
  }

  Future<bool> pushQueueToServerAsync() async {
    NetworkStatus erCode;
    String? response;

    inProgress = true;
    if (await connectAsync() == false) {
      inProgress = false;
      return false;
    }

    for (DbRecord item in outputQueue) {
      if (item is User) {
        (response, erCode) = await loadDataFromSourceAsync(
            method: HttpMethod.post,
            url: "user/set",
            jsonHeaders: {
              'Content-Type': 'application/json',
              'Authorization': token!.authHeader()
            },
            jsonBody: item.toJson(withPhones: true));

        if (response != null && erCode == NetworkStatus.ok) {
          Console.printColor(PrintColor.green, "OK");
        } else {
          inProgress = false;
          return false;
        }
      }
    }
    inProgress = false;
    return true;
  }

  Future<bool> connectAsync() async {
    NetworkStatus erCode;
    String? response;
    if (token != null && token!.isExpired() == false && connected) {
      Console.printColor(PrintColor.grey, "Token still valid");
      return true;
    }
    Console.printColor(PrintColor.white, "Ask new token");

    (response, erCode) = await loadDataFromSourceAsync(
        method: HttpMethod.post,
        url: "token/authenticate",
        jsonBodyFields: {
          'client_id': 'xxxx',
          'client_secret': 'xxxx',
          'grant_type': 'client_credentials',
          'scope': 'toto.Read'
        });

    if (response != null && erCode == NetworkStatus.ok) {
      Console.printColor(PrintColor.green, "Token received");
      token = Token.fromJson(jsonDecode(response));
      return true;
    }
    return false;
  }

  Future<String?> getUpdatesAsync() async {
    String? response;
    inProgress = true;
    if (await connectAsync() == false) {
      inProgress = false;
      return null;
    }
    assert(token != null);

    (response, _) = await loadDataFromSourceAsync(
        method: HttpMethod.get,
        url: "device/fetch",
        jsonHeaders: {'Authorization': token!.authHeader()});

    inProgress = false;
    return response;
  }

  Future<void> updateFromNetwork() async {
    String? jsonRaw;
    networkStatusControler.status =
        networkStatusControler.status.binarySet(NetworkStatusControler.receive);

    Console.printColor(PrintColor.grey, "update users from API...");

    if (server.inProgress) {
      Console.printColor(PrintColor.grey, "update users from API",
          PrintColor.yellow, "canceled");
      networkStatusControler.status =
          networkStatusControler.status.binarySet(NetworkStatusControler.error);
      return;
    }
    jsonRaw = await server.getUpdatesAsync();
    if (jsonRaw == null) {
      Console.printColor(PrintColor.grey, "update users from API",
          PrintColor.yellow, "canceled");
      networkStatusControler.status =
          networkStatusControler.status.binarySet(NetworkStatusControler.error);
      return;
    }
    Users importedUsers = Users();
    Map<String, dynamic> jsonData = jsonDecode(jsonRaw);
    List<dynamic> tmpUsers = jsonData['users'];
    List<User> usersToDelete = [];
    importedUsers.fromJson(
        tmpUsers.map((element) => element as Map<String, dynamic>).toList(),
        withPhones: true);

    users.listUsers ??= [];
    importedUsers.listUsers ??= [];
    // replace existing user
    for (User importedUser in importedUsers.listUsers!) {
      User? localUser;
      localUser = users.listUsers!.firstWhereOrNull(
        (element) => element.sID == importedUser.sID,
      );

      if (localUser != null) {
        if (importedUser.rowStatus.binaryIsSet(DbRecord.rowStatusDeleted)) {
          usersToDelete.add(localUser);
        } else {
          await localUser.fromDatabase(withPhones: true);
          //print(">>>${localUser.hashCode} ${importedUser.hashCode}");
          /* print("${localUser.sID.hashCode} ${importedUser.sID.hashCode}");
            print(
                "${localUser.dCreated.hashCode} ${importedUser.dCreated.hashCode}");
            print(
                "${localUser.rowStatus.hashCode} ${importedUser.rowStatus.hashCode}");
            print(
                "${localUser.firstName.hashCode} ${importedUser.firstName.hashCode}");
            print(
                "${localUser.lastName.hashCode} ${importedUser.lastName.hashCode}");
            print(
                "${localUser.compagny.hashCode} ${importedUser.compagny.hashCode}");
            print(
                "${localUser.status.hashCode} ${importedUser.status.hashCode}");
            print(
                "${localUser.credentials.hashCode} ${importedUser.credentials.hashCode}");
            print(
                "${localUser.category.hashCode} ${importedUser.category.hashCode}"); */

          if (localUser.hashCode != importedUser.hashCode) {
            localUser.displayAs = DbRecord.displayAsUpdated;
          }
          localUser
            ..updateFrom(importedUser)
            ..updated = true;

          localUser.listPhones
              .where((element) =>
                  element.rowStatus.binaryIsNotSet(DbRecord.rowStatusDeleted))
              .forEach((element) {
            element.updated = true;
          });

          await localUser.toDatabase(
            sync: true,
          );

          /* print(
              "Import ${localUsers.first.lastName} ${localUsers.first.firstName}"); */
        }
      }
      importedUser.rowStatus = 99; // to mark as to be deleted
    }
    // delete in local DB
    for (var user in usersToDelete) {
      await users.remove(user);
    }
    usersToDelete.clear();

    //delete user just imported
    importedUsers.listUsers!.removeWhere((element) => element.rowStatus == 99);

    // delete user deleted and not in the local database
    importedUsers.listUsers!.removeWhere(
        (element) => element.rowStatus.binaryIsSet(DbRecord.rowStatusDeleted));

    // add new users
    for (User user in importedUsers.listUsers!) {
      print("Import ${user.lastName} ${user.firstName}");
      user.displayAs = DbRecord.displayAsNew;
      user.updated = true;
      await user.toDatabase(sync: true);
    }
    users.listUsers!.addAll(importedUsers.listUsers!.toList());
    users.sortUsers();

    controllerRefreshUsers.add(StreamPageUpdate
        .reloadData); // to refresh item even if this page was rebuild
    Console.printColor(
        PrintColor.grey, "update users from API", PrintColor.white, "OK\n");
    networkStatusControler.status =
        networkStatusControler.status.binaryUnset(NetworkStatusControler.error);
    networkStatusControler.status = networkStatusControler.status
        .binaryUnset(NetworkStatusControler.receive);
  }
}

class NetworkStatusControler extends ChangeNotifier {
  static const int disable = 0;
  static const int enable = 1;
  static const send = 2;
  static const receive = 4;
  static const error = 8;

  Timer? timerUpdate;

  int _status = 0;
  int get status => _status;

  set status(int value) {
    _status = value;
    notifyListeners();
  }
}
*/