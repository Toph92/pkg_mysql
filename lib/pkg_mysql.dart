/// Support for doing something awesome.
///
/// More dartdocs go here.
library;

export 'src/pkg_mysql_base.dart';
import 'package:mysql_client/mysql_client.dart';
//import 'package:pkg_utils/pkg_utils.dart';
import 'package:pkg_utils/extensions.dart';

class DbStorage {
  MySQLConnection? _connect;
  final String host;
  final int port;
  final String username;
  final String password;
  final String databaseName;

  DbStorage(
      {required this.host,
      this.port = 3306,
      required this.username,
      required this.password,
      required this.databaseName});

  Future<void> open() async {
    if (_connect != null) return;
    try {
      _connect = await MySQLConnection.createConnection(
          host: host,
          port: port,
          userName: username,
          password: password,
          databaseName: databaseName, // optional
          secure: false);
    } catch (e) {
      print(e);
    }
    await _connect?.connect();
  }

  Future<void> close() async {
    await _connect?.close();
    _connect = null;
  }

  Future<List<Map<String, dynamic>>> fromDatabase(
      {required String sTable,
      List<String>? columns,
      String? where,
      List<Object?>? whereValues,
      int? limit,
      String? orderBy}) async {
    //assert(await testDelay());

    List<Map<String, dynamic>> results = [];

    String sql = "select ";
    if (columns != null) {
      for (String col in columns) {
        sql += "$col,";
      }
      sql = sql.left(sql.length - 1);
    } else {
      sql += "* ";
    }
    sql += "from $sTable";
    if (where != null) {
      sql += "where $where";
      assert(whereValues != null);
      sql += "${replaceParams(where, whereValues!)} ";
    }
    if (orderBy != null) {
      sql += "$orderBy ";
    }
    if (limit != null) {
      sql += "limit $limit";
    }

    await open();
    dynamic res = await _connect?.execute(sql);

    for (final row in res.rows) {
      Map<String, dynamic> mapRow = {};
      for (final col in res.cols) {
        mapRow[col.name] = row.colByName(col.name);
        /*if (row.colByName(col.name) != null) {
           switch (col.type.intVal) {
            case 3: // int
              im.setField(Symbol(colname), int.parse(row.colByName(col.name)));
              break;
            case 5: // double
              im.setField(
                  Symbol(colname), double.parse(row.colByName(col.name)));
              break;
            case 8: // bigint unsigned
              im.setField(
                  Symbol(colname), BigInt.parse(row.colByName(col.name)));
              break;
            case 253: //varchar
            case 252: //text
              im.setField(Symbol(colname), row.colByName(col.name));
              break;
            case 12: //date
              im.setField(
                  Symbol(colname), DateTime.parse(row.colByName(col.name)));
              break;
            default:
          } 
        }*/
      }
      results.add(mapRow);
    }
    return results;
  }

  Future<dynamic> toDatabase(
      {required String tableName,
      required Map<String, dynamic> json,
      required String idColName}) async {
    String sql = '';
//    bool bUpdate = false;
    dynamic idValue;

    json.forEach((k, v) {
      if (v != null) {
        if (k == idColName) idValue = v;
        if (v is String) {
          sql += "$k=${v.toSql()},";
        } else if (v is DateTime) {
          sql += "$k='${v.toString()}',";
        } else {
          sql += "$k=$v,";
        }
      }
    });
    sql = sql.left(sql.length - 1);
    if (idValue != null) {
      sql =
          "update $tableName set $sql where $idColName=${idValue is String ? 'idValue' : idValue}";
    } else {
      sql = "insert into $tableName set $sql";
    }

    await open();
    dynamic res = await _connect?.execute(sql);
    idValue ??= res.lastInsertID;
    return idValue;
  }

  String replaceParams(String request, List<dynamic> values) {
    int index = 0;

    // Vérification du nombre de paramètres
    int nbParametresDansRequete = RegExp(r'\?').allMatches(request).length;
    if (nbParametresDansRequete != values.length) {
      throw ArgumentError(
          'Le nombre de paramètres dans la requête ne correspond pas '
          'au nombre de valeurs fourni.');
    }

    for (var valeur in values) {
      index = request.indexOf('?', index);
      if (index == -1) break;
      if (valeur is String) {
        request = request.replaceRange(index, index + 1, "'$valeur'");
        index +=
            valeur.length + 2; // Pour prendre en compte les guillemets ajoutés
      } else {
        request = request.replaceRange(index, index + 1, valeur.toString());
        index += valeur.toString().length;
      }
    }
    return request;
  }

  Future<dynamic>? execute(String sql, {bool trace = false}) async {
    await open();
    dynamic res;
    trace == true ? print(sql) : {};
    try {
      res = await _connect?.execute(sql);
    } catch (e) {
      print(e.toString());
      res = null;
    }
    return res;
  }

  Future<String> queryValue(String sql, {bool trace = false}) async {
    dynamic res;
    String result = "";
    assert(sql.toLowerCase().contains("limit 1"));
    res = await execute(sql, trace: trace);
    for (final row in res.rows) {
      result = row.colAt(0);
      break;
    }
    return await Future(() => result);
  }
}

extension SQLListExtensionString on List<String> {
  // Copyright ChatGPT :)
  String toSql() {
    final values = map((item) => "'$item'").join(',');
    return values;
  }
}

extension SQLListExtensionNumber on List<num> {
  // Copyright ChatGPT
  String toSql() {
    final values = map((item) => "$item").join(',');
    return values;
  }
}
