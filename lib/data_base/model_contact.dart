
import 'package:objectbox/objectbox.dart';



@Entity()
class Contact {

  @Id()
  int id = 0;

  String? userName;

  String? phoneNumber;

  String? imageType;

  Contact({required this.userName, required this.phoneNumber});


}
