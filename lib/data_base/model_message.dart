
import 'package:objectbox/objectbox.dart';



@Entity()
class Message {

  @Id()
  int id = 0;

  String receiverId;

  String senderPhoneNumber;

  String senderUserName;

  String message;

  @Property(type: PropertyType.date) // Store as int in milliseconds
  DateTime? date;

  Message({
    required this.message,
    required this.receiverId,
    required this.senderPhoneNumber,
    required this.senderUserName,
    required this.date
});


}
