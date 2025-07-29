library;

//import 'package:mysql_client/mysql_client.dart' as mysql;
import 'package:postgres/postgres.dart' as postgres;
//import 'package:pkg_utils/pkg_utils.dart';
import 'package:pkg_utils/extensions.dart';

enum DbType {
  mysql,
  postgres,
}

abstract class DbObject {
  BigInt? id;
  DateTime? dCreated;
  DateTime? dUpdated;
  String? tableName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dCreated': dCreated,
        'dUpdated': dUpdated,
      };

  void fromJson(Map<String, dynamic> json) {
    id = json["id"] != null ? json["id"] as BigInt : null;
    dCreated =
        json['dCreated'] != null ? DateTime.parse(json['dCreated']) : null;
    dUpdated =
        json['dUpdated'] != null ? DateTime.parse(json['dUpdated']) : null;
  }

  ({Map<String, dynamic> json, String tableName}) toDatabase() {
    assert(tableName != null);
    assert(toJson().length > 3); // more than id, dCreated, dUpdated columns
    if (id == null) {
      dCreated = DateTime.now();
    } else {
      dCreated = dCreated ?? DateTime.now();
    }
    return (json: toJson(), tableName: tableName!);
  }

  void fromDatabase(Map<String, dynamic> json) {
    assert(tableName != null);
    assert(id != null);
    fromJson(json);
  }
}

class DbStorage {
  dynamic _connect;
  final String host;
  final int port;
  final String username;
  final String password;
  final String databaseName;
  final DbType dbType;

  DbStorage(
      {required this.host,
      this.port = 3306,
      required this.username,
      required this.password,
      required this.databaseName,
      required this.dbType});

  Future<void> open() async {
    if (_connect != null) return;
    try {
      switch (dbType) {
        case DbType.mysql:
          /* _connect = await mysql.MySQLConnection.createConnection(
            host: host,
            port: port,
            userName: username,
            password: password,
            databaseName: databaseName, // optional
            secure: false,
          );
          await _connect?.connect(); */
          break;
        case DbType.postgres:
          _connect = await postgres.Connection.open(
            postgres.Endpoint(
              host: host,
              database: databaseName,
              username: username,
              password: password,
            ),
            settings:
                postgres.ConnectionSettings(sslMode: postgres.SslMode.disable),
          );
          break;
      }
    } catch (e) {
      _connect = null;
      print(e);
    }
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

  /// Formate une valeur pour l'utilisation dans une requête SQL
  String _formatSqlValue(dynamic value) {
    if (value == null) {
      return "NULL";
    } else if (value is String) {
      return "'${value.replaceAll("'", "''")}'";
    } else if (value is DateTime) {
      return "'${value.toIso8601String()}'";
    } else {
      return value.toString();
    }
  }

  Future<dynamic> toDatabase(
      /*({Map<String, dynamic> json, String tableName}) object, */
      DbObject object,
      {String idColName = 'id'}) async {
    dynamic idValue;
    List<String> fieldsNames = [];
    List<dynamic> fieldsValues = [];
    Map<String, dynamic> json = object.toJson();

    // Extraire l'ID et préparer les champs
    json.forEach((k, v) {
      if (k == idColName) {
        idValue = v;
      } else {
        fieldsNames.add(k);
        fieldsValues.add(v);
      }
    });

    String sql = '';

    if (idValue != null) {
      // UPDATE: construire la clause SET
      List<String> setParts = [];
      for (int i = 0; i < fieldsNames.length; i++) {
        String fieldName = fieldsNames[i];
        dynamic fieldValue = fieldsValues[i];
        setParts.add("$fieldName=${_formatSqlValue(fieldValue)}");
      }

      String whereClause = "$idColName=${_formatSqlValue(idValue)}";
      sql =
          "UPDATE ${object.tableName} SET ${setParts.join(',')} WHERE $whereClause";
    } else {
      // INSERT: construire la requête d'insertion
      List<String> valuesParts =
          fieldsValues.map((value) => _formatSqlValue(value)).toList();

      switch (dbType) {
        case DbType.mysql:
          sql =
              "INSERT INTO ${object.tableName} (${fieldsNames.join(',')}) VALUES (${valuesParts.join(',')})";
          break;
        case DbType.postgres:
          sql =
              "INSERT INTO ${object.tableName} (${fieldsNames.join(',')}) VALUES (${valuesParts.join(',')}) RETURNING $idColName";
          break;
      }
    }

    await open();
    dynamic res = await _connect?.execute(sql);

    // Retourner l'ID (existant pour update, nouveau pour insert)
    if (idValue != null) {
      return idValue;
    } else {
      switch (dbType) {
        case DbType.mysql:
          return res.lastInsertID;
        case DbType.postgres:
          // Pour PostgreSQL, l'ID est retourné directement dans le résultat de la requête RETURNING
          if (res.isNotEmpty) {
            return res.first.first; // Premier enregistrement, première colonne
          }
          return null;
      }
    }
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
      await close();
      res = null;
      rethrow;
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
