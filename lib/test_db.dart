import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dbPath = '/home/christof/.local/share/ja_manga.db'; // the db path might be standard
  print(dbPath);
}
