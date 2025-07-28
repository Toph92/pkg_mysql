import 'package:example/example.dart' as example;

import 'package:pkg_mysql/pkg_mysql.dart';
import 'dart:io';

DbStorage db = DbStorage(
  host: 'iSrv1',
  username: 'sa',
  password: 'idefix',
  databaseName: 'test',
  dbType: DbType.postgres,
);

void main(List<String> arguments) async {
  await db.execute(
    "create table if not exists test ("
    "id bigint unsigned not null auto_increment unique, "
    "dCreated datetime default current_timestamp(), "
    "dUpdated timestamp not null default current_timestamp() on update current_timestamp(), "
    "name varchar(100) default null, "
    "age integer default null, "
    "primary key (id)) "
    "engine=InnoDB default charset=utf8mb4;",
  );
  await db.execute("truncate table test");
  await db.execute("insert into test (name, age) values ('start', 1);");
  /* print('Stop database, appuyez sur Entrée pour continuer...');
  stdin.readLineSync(); */

  await db.execute(
    "insert into test (name, age) values ('poubelle', 2);",
  ); // poubelle car db arrêtée

  /* print('Start database, appuyez sur Entrée pour continuer...');
  stdin.readLineSync(); */

  await db.execute(
    "insert into test (name, age) values ('OK', 3);",
  ); // poubelle car db arrêtée

  await db.close();
  print("Terminé");
}
