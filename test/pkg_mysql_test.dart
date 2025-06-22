import 'package:pkg_mysql/pkg_mysql.dart';
import 'package:test/test.dart';

DbStorage db = DbStorage(
    host: 'iSrv1', username: 'sa', password: 'idefix', databaseName: 'test');

class Test {
  BigInt? id;
  DateTime? dCreated;
  DateTime? dUpdated;
  String? name;
  int? age;

  Test();

  Future<void> toDatabase() async {
    await db.open();
    id =
        await db.toDatabase(tableName: 'test', json: toJson(), idColName: 'id');
    await db.close();
  }

  Future fromDatabase() async {
    await db.open();
    fromJson(await db.fromDatabase(sTable: ('test')));
    await db.close();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dCreated': dCreated,
        'dUpdated': dUpdated,
        'name': name,
        'age': age
      };

  fromJson(Map<String, dynamic> json) {
    id = json["id"] != null ? json["id"] as BigInt : null;
    dCreated = json['dCreated'];
    dUpdated = json['dUpdated'];
    name = json['name'];
    age = json["age"];
  }
}

void main() {
  String sqlQuery = """CREATE TABLE `test` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE,
  `dCreated` datetime DEFAULT current_timestamp(),
  `dUpdated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `name` varchar(100) DEFAULT NULL,
  `age` integer default null,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;""";

  test('Create table', () async {
    await db.open();
    await db.execute("drop table if exists test");
    await db.execute(sqlQuery);
    await db.execute("ALTER TABLE test AUTO_INCREMENT= 1000000000000000000");

    String sTmp = await db.queryValue("select count(*) from test limit 1");
    expect(sTmp, "0");
    await db.close();
  });

  test('write objets with toDatabase', () async {
    await db.open();
    await db.execute("truncate test");
    for (int i = 0; i < 100; i++) {
      Test test = Test()
        ..dCreated = DateTime.now()
        ..dUpdated = DateTime.now()
        ..name = "Desbois"
        ..age = i;
      await test.toDatabase();
      assert(test.id != null);
    }
    await db.close();
  });

  test('update objets with toDatabase', () async {
    await db.open();
    await db.execute("truncate test");
    Test test = Test()
      ..dCreated = DateTime.now()
      ..dUpdated = DateTime.now()
      ..name = "Desbois"
      ..age = 55;
    await test.toDatabase();
    test.name = 'Desbois Christophe';
    await test.toDatabase();
    await db.close();
  });

  test('read objets with fromDatabase', () async {
    BigInt? id;
    await db.open();
    await db.execute("truncate test");
    Test? test = Test()
      ..dCreated = DateTime.now()
      ..dUpdated = DateTime.now()
      ..name = "Desbois"
      ..age = 55;
    await test.toDatabase();
    id = test.id;
    assert(id != null);

    test = null;
    test = Test()..id = id;
    await test.fromDatabase();
    await db.close();

    expect(test.name, "Desbois");
  });

  test('fill listFromDatabase', () async {
    await db.open();
    await db.execute("truncate test");
    for (int i = 0; i < 100; i++) {
      Test test = Test()
        ..dCreated = DateTime.now()
        ..dUpdated = DateTime.now()
        ..name = "Desbois"
        ..age = i;
      await test.toDatabase();
      assert(test.id != null);
    }

    List<Map<String, dynamic>> jsonList = await db.listFromDatabase(
        sTable: 'test', idColName: 'id', columns: ['id', 'name', 'age']);

    List<Test> list = [];
    for (Map<String, dynamic> json in jsonList) {
      list.add(Test()..fromJson(json));
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
      Test test = Test()
        ..dCreated = DateTime.now()
        ..dUpdated = DateTime.now()
        ..name = "Desbois"
        ..age = i;
      await test.toDatabase();
      assert(test.id != null);
    }

    List<Map<String, dynamic>> jsonList = await db.listFromDatabase(
        sTable: 'test',
        idColName: 'id',
        columns: ['id', 'name', 'age'],
        where: "age<?",
        whereValues: [50]);

    List<Test> list = [];
    for (Map<String, dynamic> json in jsonList) {
      list.add(Test()..fromJson(json));
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
      Test test = Test()
        ..dCreated = DateTime.now()
        ..dUpdated = DateTime.now()
        ..name = "Desbois $i"
        ..age = i;
      await test.toDatabase();
      assert(test.id != null);
    }

    List<Map<String, dynamic>> jsonList = await db.listFromDatabase(
        sTable: 'test',
        idColName: 'id',
        columns: ['id', 'name', 'age'],
        where: "age=? and name=?",
        whereValues: [50, 'Desbois 50']);

    List<Test> list = [];
    for (Map<String, dynamic> json in jsonList) {
      list.add(Test()..fromJson(json));
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
      Test test = Test()
        ..dCreated = DateTime.now()
        ..dUpdated = DateTime.now()
        ..name = "Desbois $i"
        ..age = i;
      await test.toDatabase();
      assert(test.id != null);
    }

    List<Map<String, dynamic>> jsonList =
        await db.listFromDatabase(sql: 'select name from test where age <= 50');

    List<Test> list = [];
    for (Map<String, dynamic> json in jsonList) {
      list.add(Test()..fromJson(json));
    }

    expect(list.last.name, 'Desbois 50');
    expect(list.last.age, null);
    expect(list.length, 51);
    await db.close();
  });
}
