
import 'package:objectbox/objectbox.dart';



@Entity()
class Group {

  @Id()
  int id = 0;

  String? groupID;

  String? groupName;

  Group({required this.groupName, required this.groupID});

  @Transient()
  List<String> image = [];


}