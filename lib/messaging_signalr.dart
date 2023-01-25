library messaging_signalr;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:signalr_core/signalr_core.dart';
import 'package:http/io_client.dart';

class Chat{

  Chat({required this.type, required this.chatName, required this.messages,this.image ,this.userName});

  ChatType type;
  List<Message> messages = [];
  String chatName;
  String? image;
  String? userName;

}


enum ChatType {
  group,
  contact,
}

class Message{

  Message({required this.sender, required this.text, required this.senderUserName }){date = DateTime.now();}

  int sender;
  String senderUserName;
  String text;
  DateTime? date;

}

class Messaging {
  Messaging.init(String serverAddress, String fireBaseToken){
    connection = HubConnectionBuilder()
        .withUrl(
        serverAddress,
        HttpConnectionOptions(
          client: IOClient(HttpClient()..badCertificateCallback = (x, y, z) => true),
          logging: (level, message) => debugPrint(message),
        ))
        .build();

    connection.start();

  }


  List<Chat> chats = [];

  int? myId;
  String? fireBaseToken;

  static final Messaging _instance = Messaging();


  factory Messaging() => _instance;


  late final HubConnection connection;


  void defineSignalrFunctions(){



    connection.on('ReceiveNewMessage', (message) async{
      debugPrint("new message received");
      int targetIndex = chats.indexWhere((e) => e.chatName == message![0].toString());
      if(targetIndex != -1){
        chats[targetIndex].messages.add( Message(sender: message![0], text: message[1], senderUserName: message[2]));
        chats.insert(0, chats[targetIndex]);
        chats.removeAt(targetIndex + 1);
      }else{
        debugPrint("send request to get image");

        debugPrint("image received");
        chats.insert(0, Chat(type: ChatType.contact, chatName: message![0].toString(), messages:
        [Message(sender: message[0], text: message[1], senderUserName: message[2],)],userName: message[2],));

      }

      debugPrint("new message received from ${message[0]}");
      debugPrint(message[1]);
    });
    connection.on('receiveUserName', (message){
      debugPrint("user name is : ${message![1]}");
      int targetChat = chats.indexWhere((element) => element.chatName == message[0].toString());
      chats[targetChat].userName = message[1];
      debugPrint("receive user name");
    });

    connection.on('GroupMessage', (message) {
      debugPrint("new message for group ${message![0]} form user ${message[1]} received, message is ${message[2]}");
      debugPrint(message[1].toString());
      int targetIndex = chats.indexWhere((e) => e.chatName == message[0]);
      if(targetIndex != -1){
        chats[targetIndex].messages.add(Message(sender: message[1], text: message[2], senderUserName: message[3]));
        chats.insert(0, chats[targetIndex]);
        chats.removeAt(targetIndex + 1);
      }else{
        debugPrint("here1");
        chats.insert(0, Chat(type: ChatType.contact, chatName: message[0].toString(), messages:
        [Message(sender: message[1], text: message[2], senderUserName: message[3]),]));
      }

    });

    connection.on('ReceiveId', (message) {
      myId = message![0];
      debugPrint("client id is $myId");
      connection.invoke('ReceiveFireBaseToken', args: [fireBaseToken]);
      debugPrint("connection status:  ${connection.state}");
      debugPrint("sending token");
    });

  }


}


