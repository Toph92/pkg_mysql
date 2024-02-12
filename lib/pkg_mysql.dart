/// Support for doing something awesome.
///
/// More dartdocs go here.
library;

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

  Future<Map<String, dynamic>> fromDatabase({
    required String sTable,
    String idColName = 'id',
    List<String>? columns,
    String? where,
    List<Object?>? whereValues,
  }) async {
    //assert(await testDelay());

    Map<String, dynamic> result = {};

    String sql = "select ";
    if (columns != null) {
      for (String col in columns) {
        sql += "$col,";
      }
      sql = sql.left(sql.length - 1);
      sql += ' ';
    } else {
      sql += "* ";
    }
    sql += "from $sTable ";
    if (where != null) {
      sql += "where $where";
      assert(whereValues != null);
      sql += "${replaceParams(where, whereValues!)} ";
    }
    sql += "limit 1";

    await open();
    dynamic res = await _connect?.execute(sql);

    for (final row in res.rows) {
      for (final col in res.cols) {
        switch (col.type.intVal) {
          case 3: // int
            result[col.name] = int.parse(row.colByName(col.name));
            break;
          case 5: // double
            result[col.name] = double.parse(row.colByName(col.name));
            break;
          case 8: // BigInt
            result[col.name] = BigInt.parse(row.colByName(col.name));
            break;
          case 7: // TimeStamp
          case 12: // DateTime
            result[col.name] = DateTime.parse(row.colByName(col.name));
            break;
          case 252:
          case 253: // String
            result[col.name] = row.colByName(col.name);
            break;
          default:
            throw UnimplementedError();
        }
      }
      break;
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> listFromDatabase(
      {String? sTable,
      String idColName = 'id',
      List<String>? columns,
      String? where,
      List<Object?>? whereValues,
      int? limit,
      String? orderBy,
      String? sql}) async {
    //assert(await testDelay());

    assert((sql != null &&
            columns == null &&
            where == null &&
            limit == null &&
            orderBy == null) ||
        sql == null && sTable != null);

    List<Map<String, dynamic>> results = [];

    if (sql == null) {
      sql = "";
      sql = "select ";
      if (columns != null) {
        for (String col in columns) {
          sql = "${sql!}$col,";
        }
        sql = sql!.left(sql.length - 1);
        sql += ' ';
      } else {
        sql += "* ";
      }
      sql += "from $sTable ";
      if (where != null) {
        sql += "where ";
        assert(whereValues != null);
        sql += "${replaceParams(where, whereValues!)} ";
      }
      if (orderBy != null) {
        sql += "order by $orderBy ";
      }
      if (limit != null) {
        sql += "limit $limit";
      }
    }

    await open();
    dynamic res = await _connect?.execute(sql);

    for (final row in res.rows) {
      Map<String, dynamic> jsonRow = {};
      for (final col in res.cols) {
        switch (col.type.intVal) {
          case 3: // int
            jsonRow[col.name] = int.parse(row.colByName(col.name));
            break;
          case 5: // double
            jsonRow[col.name] = double.parse(row.colByName(col.name));
            break;
          case 8: // BigInt
            jsonRow[col.name] = BigInt.parse(row.colByName(col.name));
            break;
          case 7: // TimeStamp
          case 12: // DateTime
            jsonRow[col.name] = DateTime.parse(row.colByName(col.name));
            break;
          case 252:
          case 253: // String
            jsonRow[col.name] = row.colByName(col.name);
            break;
          default:
            throw UnimplementedError();
        }
      }
      results.add(jsonRow);
    }
    return results;
  }

  Future<dynamic> toDatabase(
      {required String tableName,
      required Map<String, dynamic> json,
      String idColName = 'id'}) async {
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
