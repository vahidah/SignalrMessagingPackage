
import 'package:objectbox/objectbox.dart';
import 'dart:io';


@Entity()
class Contact {

  @Id()
  int id = 0;

  String? userName;

  String? phoneNumber;

  Contact({required this.userName, required this.phoneNumber});

  @Transient()
  File? image;


}
