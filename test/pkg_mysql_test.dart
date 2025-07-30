import 'dart:math';

import 'package:pkg_mysql/pkg_mysql.dart';
import 'package:test/test.dart';

/* DbStorage db = DbStorage(
    host: 'iSrv1',
    username: 'sa',
    password: 'idefix',
    databaseName: 'test',
    dbType: DbType.mysql);
 */
DbStorage db = DbStorage(
    host: 'iSrv1',
    username: 'root',
    password: 'idefix911',
    databaseName: 'tests',
    dbType: DbType.postgres);

class User extends DbObject {
  String? name;
  DateTime? birthdate;
  int? age;
  double? height;

  User() {
    tableName = 'users';
  }

  @override
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = super.toJson();
    json['name'] = name;
    json['age'] = age;
    json['height'] = height;
    json['birthdate'] = birthdate;
    return json;
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    name = json['name'] as String?;
    age = json['age'] as int?;
    height = json['height'] as double?;
    birthdate = json['birthdate'] != null
        ? DateTime.parse(json['birthdate'] as String)
        : null;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    User user = User();
    user.fromJson(json);
    return user;
  }
}

void main() {
  test('Create table', () async {
    await db.open();
    String sql;
    switch (db.dbType) {
      case DbType.mysql:
        sql = '''
          CREATE TABLE users (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        dCreated DATETIME,
        dUpdated DATETIME,
    name VARCHAR(255),    
    age INT,
    height DOUBLE,
    birthdate DATETIME
)''';
        break;
      case DbType.postgres:
        sql = '''
      CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    dCreated TIMESTAMP,
    dUpdated TIMESTAMP,
    name VARCHAR,    
    age INT,
    height DOUBLE PRECISION,
    birthdate TIMESTAMP
)''';
        break;
    }

    //await db.execute('DROP TABLE IF EXISTS users');
    await db.execute('DROP TABLE IF EXISTS users;');
    await db.execute(sql);
    //await db.execute("ALTER TABLE test AUTO_INCREMENT= 1000000000000000000");

    //String sTmp = await db.queryValue("select count(*) from test limit 1");
    //expect(sTmp, "0");
    await db.close();
  });

  test('write objet to toDatabase', () async {
    await db.open();
    await db.execute("truncate users");

    User test = User()
      ..dCreated = DateTime.now()
      ..dUpdated = DateTime.now()
      ..name = "Desbois"
      ..birthdate = DateTime(1968, 8, 14)
      ..height = 1.75
      ..age = 56;
    await db.toDatabase(test);
    await db.close();
    expect(test.id, isNull);
  });

  test('write objet to toDatabase and update id', () async {
    await db.open();
    await db.execute("truncate users");

    User test = User()
      ..dCreated = DateTime.now()
      ..dUpdated = DateTime.now()
      ..name = "Desbois"
      ..birthdate = DateTime(1968, 8, 14)
      ..height = 1.75
      ..age = 56;
    await db.toDatabase(test, options: [DbOptions.updateID]);
    await db.close();
    expect(test.id, isNotNull);
  });

  test('write objet to toDatabase with specifique ID', () async {
    await db.open();
    await db.execute("truncate users");
    User test = User()
      ..dCreated = DateTime.now()
      ..dUpdated = DateTime.now()
      ..name = "Desbois"
      ..birthdate = DateTime(1968, 8, 14)
      ..height = 1.75
      ..age = 56
      ..id = BigInt.from(1000000000000000000);
    await db.toDatabase(test, options: [DbOptions.forceInsert]);
    await db.close();
  });

  test('read object  by ID', () async {
    await db.open();
    await db.execute("truncate users");
    User test = User()
      ..dCreated = DateTime.now()
      ..dUpdated = DateTime.now()
      ..name = "Desbois"
      ..birthdate = DateTime(1968, 8, 14)
      ..height = 1.75
      ..age = 56
      ..id = BigInt.from(10);
    await db.toDatabase(test, options: [DbOptions.forceInsert]);

    test = await db.fromDatabase(10);

    //await test.fromDatabase();
    await db.close();
  });

  test('read objets with fromDatabase', () async {
    /*
    await db.open();
    await db.execute("truncate test");
    User? test = User()
      ..dCreated = DateTime.now()
      ..dUpdated = DateTime.now()
      ..name = "Desbois"
      ..age = 55;
    test.toDatabase();
    id = test.id;

    test = null;
    test = User()..id = id;
    test.fromDatabase();
    await db.close();

    expect(test.name, "Desbois"); */
  });

  /* test('fill listFromDatabase', () async {
    await db.open();
    await db.execute("truncate test");
    for (int i = 0; i < 100; i++) {
      User test = User()
        ..dCreated = DateTime.now()
        ..dUpdated = DateTime.now()
        ..name = "Desbois"
        ..age = i;
      test.toDatabase();
      assert(test.id != null);
    }

    List<Map<String, dynamic>> jsonList = await db.listFromDatabase(
        sTable: 'test', idColName: 'id', columns: ['id', 'name', 'age']);

    List<User> list = [];
    for (Map<String, dynamic> json in jsonList) {
      list.add(User()..fromJson(json));
    }

    expect(list.first.name, 'Desbois');
    expect(list.last.age, 99);
    expect(list.length, 100);
    await db.close();
  });
  test('fill listFromDatabase with int criteria', () async {
    await db.open();
    await db.execute("truncate test");
    for (int i = 0; i < 100; i++) {
      User test = User()
        ..dCreated = DateTime.now()
        ..dUpdated = DateTime.now()
        ..name = "Desbois"
        ..age = i;
      test.toDatabase();
      assert(test.id != null);
    }

    List<Map<String, dynamic>> jsonList = await db.listFromDatabase(
        sTable: 'test',
        idColName: 'id',
        columns: ['id', 'name', 'age'],
        where: "age<?",
        whereValues: [50]);

    List<User> list = [];
    for (Map<String, dynamic> json in jsonList) {
      list.add(User()..fromJson(json));
    }

    expect(list.first.name, 'Desbois');
    expect(list.last.age, 49);
    expect(list.length, 50);
    await db.close();
  });

  test('fill listFromDatabase with string criteria', () async {
    await db.open();
    await db.execute("truncate test");
    for (int i = 0; i < 100; i++) {
      User test = User()
        ..dCreated = DateTime.now()
        ..dUpdated = DateTime.now()
        ..name = "Desbois $i"
        ..age = i;
      test.toDatabase();
      assert(test.id != null);
    }

    List<Map<String, dynamic>> jsonList = await db.listFromDatabase(
        sTable: 'test',
        idColName: 'id',
        columns: ['id', 'name', 'age'],
        where: "age=? and name=?",
        whereValues: [50, 'Desbois 50']);

    List<User> list = [];
    for (Map<String, dynamic> json in jsonList) {
      list.add(User()..fromJson(json));
    }

    expect(list.first.name, 'Desbois 50');
    expect(list.first.age, 50);
    expect(list.length, 1);
    await db.close();
  });

  test('fill listFromDatabase with sql criteria', () async {
    await db.open();
    await db.execute("truncate test");
    for (int i = 0; i < 100; i++) {
      User test = User()
        ..dCreated = DateTime.now()
        ..dUpdated = DateTime.now()
        ..name = "Desbois $i"
        ..age = i;
      test.toDatabase();
      assert(test.id != null);
    }

    List<Map<String, dynamic>> jsonList =
        await db.listFromDatabase(sql: 'select name from test where age <= 50');

    List<User> list = [];
    for (Map<String, dynamic> json in jsonList) {
      list.add(User()..fromJson(json));
    }

    expect(list.last.name, 'Desbois 50');
    expect(list.last.age, null);
    expect(list.length, 51);
    await db.close();
  }); */
}
