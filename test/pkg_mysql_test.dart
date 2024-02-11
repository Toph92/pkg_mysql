import 'package:pkg_mysql/pkg_mysql.dart';
import 'package:test/test.dart';

DbStorage db = DbStorage(
    host: 'macmini', username: 'sa', password: 'idefix', databaseName: 'SA');

class Test {
  BigInt? id;
  DateTime? dCreated;
  DateTime? dUpdated;
  String? name;
  int? age;

  Future<void> toDatabase() async {
    await db.open();
    id =
        await db.toDatabase(tableName: 'test', json: toJson(), idColName: 'id');
    await db.close();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dCreated': dCreated,
        'dUpdated': dUpdated,
        'name': name,
        'age': age
      };
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
  group('A group of tests', () {
    test('Create table', () async {
      await db.open();
      await db.execute("drop table if exists test");
      await db.execute(sqlQuery);
      await db.execute("ALTER TABLE test AUTO_INCREMENT= 1000000000000000000");

      String sTmp = await db.queryValue("select count(*) from test limit 1");
      expect(sTmp, "0");
      await db.close();
    });

    test('create toDatabase', () async {
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

    test('update toDatabase', () async {
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

    test('Create list from query', () async {
      List<Map<String, dynamic>> results;
      await db.open();
      results = await db.fromDatabase(
        sTable: 'persons',
      );
      await db.close();
      for (var element in results) {}
    });
  });
}
