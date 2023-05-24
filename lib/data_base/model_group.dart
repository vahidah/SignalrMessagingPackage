
import 'package:objectbox/objectbox.dart';



@Entity()
class Group {

  @Id()
  int id = 0;

  String? groupID;

  String? groupName;

  String? imageType;

  Group({required this.groupName, required this.groupID});


}