import 'package:pkg_mysql/pkg_mysql.dart';
import 'package:test/test.dart';
import 'package:pkg_mysql/pkg_mysql.dart';

DbStorage db = DbStorage(
    host: 'macmini',
    username: 'root',
    password: 'idefix911',
    databaseName: 'SA');

void main() {
  group('A group of tests', () {
    test('First Test', () {
      db.fromDatabase(
        sTable: 'persons',
      );
      //expect(awesome.isAwesome, isTrue);
    });
  });
}
