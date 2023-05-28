
import 'package:objectbox/objectbox.dart';
import 'dart:io';


@Entity()
class Membership {

  @Id()
  int id = 0;

  String? groupId;

  String? userPhone;

  Membership({required this.groupId, required this.userPhone});



}