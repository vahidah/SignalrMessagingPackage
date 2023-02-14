library messaging_signalr;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:signalr_core/signalr_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';

class Chat {
  Chat({required this.type, required this.chatId, required this.messages, this.image, this.userName});

  ChatType type;
  List<Message> messages = [];
  String chatId; // group name for groups and id of contact for private chats
  String? image;
  String? userName; //this is just for private chat
  //todo may this is good idea to separate this two class check it later
}

enum ChatType {
  group,
  contact,
}

class Message {
  Message({required this.sender, required this.text, required this.senderUserName}) {
    date = DateTime.now();
  }

  int sender;
  String senderUserName;
  String text;
  DateTime? date;
}



class SignalRMessaging {

  SignalRMessaging._();

  static final SignalRMessaging _instance = SignalRMessaging._();

  factory SignalRMessaging() => _instance;

  late final HubConnection connection;

  List<Chat> chats = [];

  int myId = -1;
  String? fireBaseToken;
  String? userName;
  File? image;
  List<int>? delayInterval;

  Function? callInReceiveNewMessage;
  Function? onSendMessage;

  // Chat? selectedChat;
  //todo make them private



  static void init(
      {required String serverAddress,
      required String firebaseToken,
      required Function eventCall,
      required Function onSendMessage}) {
    _instance.delayInterval = [];
    for(int i = 0; i < 1000; i++){
      _instance.delayInterval?.add(1000);
    }


    _instance.connection = HubConnectionBuilder()
        .withUrl(
            serverAddress,
            HttpConnectionOptions(
              client: IOClient(HttpClient()..badCertificateCallback = (x, y, z) => true),
              //todo remove bad certificate and and check reconnection
              logging: (level, message) => debugPrint(message),
            )).withAutomaticReconnect(_instance.delayInterval)
        .build();
    _instance.onSendMessage = onSendMessage;
    _instance.fireBaseToken = firebaseToken;
    _instance.callInReceiveNewMessage = eventCall;
    _instance.defineSignalrFunctions();
    _instance.connection.start();

  }





  Future<void> sendMessage({required bool privateChat, required String message, required chatId}) async {


    Chat targetChat = chats.singleWhere((element) => element.chatId == chatId);


    if (privateChat) {

      targetChat.messages.add(Message(sender: myId, text: message, senderUserName: userName!));
      connection.invoke('sendMessage', args: [int.parse(chatId), message, false]);
    } else {
      //todo he himself receive message from remote server? i think it should change!
      connection.invoke('SendMessageToGroup', args: [ chatId, myId, message]);
    }
    onSendMessage!();
  }

  ///crete group [myId]
  void createGroup({required String newGroupName}) {
    if (!chats.any((element) => element.chatId == newGroupName)) {
      chats.add(Chat(type: ChatType.group, chatId: newGroupName, messages: []));
      connection.invoke('AddToGroup', args: [newGroupName]);
      callInReceiveNewMessage!();
    }
  }

  ///[image] must be set null when you set [haveImage] null otherwise you have to provide image
  Future<void> sendContactName({File? image, required String userName}) async {

    try {
      if(image != null) {
        BaseOptions options = BaseOptions(
            receiveDataWhenStatusError: true,
            connectTimeout: 5 * 1000, // 60 seconds
            receiveTimeout: 5 * 1000 // 60 seconds
        );

        Dio dio = Dio(options);
        //todo make structure for package and move http request from here and check exceptions
        // (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (HttpClient client) {
        //   client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        //   return client;
        // };
        this.image = image;
        FormData map = FormData.fromMap(
            {"file": await MultipartFile.fromFile(image.path, filename: image.path
                .split('/')
                .last), "id": myId});

        debugPrint("dio send request");
        final response = await dio.post("http://10.0.2.2:5003/api/Image",
            data: map);

        debugPrint("status code is ${response.statusCode}");

        if (response.statusCode == 200) {
          debugPrint("successfully upload image");
        } else {
          debugPrint("upload image failed response from server gotten");
        }
      }
    } catch (e, t) {
      debugPrint("upload image failed");
      debugPrint(e.toString());
      rethrow;
    }finally{
      debugPrint("we cant catch these piece of code?");
      this.userName = userName;
      debugPrint("sending user name $userName}");
      try {
        connection.invoke('ReceiveUserName', args: [this.userName, myId]);
      } catch (e, t) {
        debugPrint("signalrConnection failed");
      }
    }


  }

  void sendFirstMessage(int contactId, String firstMessage) async {
    String? base64Image;

    debugPrint("package: in sendFirstMessage 1");
    try {
      http.Response response = await http.post(
        Uri.parse(
          "${"http://10.0.2.2:5003/api/Image"}/$contactId",
        ),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        base64Image = base64.encode(response.bodyBytes);
      } else {
        debugPrint("get image failed");
      }
    }catch(e){
      debugPrint("what happened? does it throw exception");
    }
    debugPrint("package: in sendFirstMessage 2");



    debugPrint("package: in sendFirstMessage 3");


    chats.insert(
        0,
        Chat(
            type: ChatType.contact,
            chatId: contactId.toString(),
            messages: [Message(sender: myId, text: firstMessage, senderUserName: userName!)],
            image: base64Image));
    //todo handle with try catch
    connection.invoke('sendMessage', args: [contactId, firstMessage, true]);

    debugPrint("package: in sendFirstMessage 4");
  }

  //call server functions end

  void defineSignalrFunctions() {
    connection.on('ReceiveNewMessage', (message) async {
      debugPrint("new message received 1");
      String? base64Image;
      int targetIndex = chats.indexWhere((e) => e.chatId == message![0].toString());
      debugPrint("new message received 2");
      if (targetIndex != -1) {
        debugPrint("new message received 3");
        chats[targetIndex].messages.add(Message(sender: message![0], text: message[1], senderUserName: message[2]));
        chats.insert(0, chats[targetIndex]);
        chats.removeAt(targetIndex + 1);
      } else {
        try {
          debugPrint("new message received 4");
          debugPrint("send request to get image");
          Map<String, String> requestHeaders = {
            "Connection": "keep-alive",
          };
          http.Response response = await http.post(
              Uri.parse(
                "http://10.0.2.2:5003/api/Image/${message![0]}",
              ),
              headers: requestHeaders).timeout(const Duration(seconds: 5));
          if(response.statusCode == 200){
            debugPrint("package: image received");
            base64Image = base64.encode(response.bodyBytes);
          }else{
            debugPrint("package: user have no image");
          }

        }catch (e){
          debugPrint("package: user have no image");
          debugPrint(e.toString());
        }finally{
          debugPrint("package: new message received 5");
          chats.insert(
              0,
              Chat(
                  type: ChatType.contact,
                  chatId: message![0].toString(),
                  messages: [
                    Message(
                      sender: message[0],
                      text: message[1],
                      senderUserName: message[2],
                    )
                  ],
                  userName: message[2],
                  image: base64Image));
        }
      }
      debugPrint("new message received 6");
      callInReceiveNewMessage!();

      debugPrint("new message received from ${message[0]}");
      debugPrint(message[1]);
    });
    connection.on('receiveUserName', (message) {
      debugPrint("user name is : ${message![1]}");
      int targetChat = chats.indexWhere((element) => element.chatId == message[0].toString());
      chats[targetChat].userName = message[1];
      debugPrint("receive user name");
      callInReceiveNewMessage!();
    });

    connection.on('GroupMessage', (message) {
      debugPrint("new message for group ${message![0]} form user ${message[1]} received, message is ${message[2]}");
      debugPrint(message[1].toString());
      int targetIndex = chats.indexWhere((e) => e.chatId == message[0]);
      if (targetIndex != -1) {
        chats[targetIndex].messages.add(Message(sender: message[1], text: message[2], senderUserName: message[3]));
        chats.insert(0, chats[targetIndex]);
        chats.removeAt(targetIndex + 1);
      } else {
        debugPrint("here1");
        chats.insert(
            0,
            Chat(type: ChatType.contact, chatId: message[0].toString(), messages: [
              Message(sender: message[1], text: message[2], senderUserName: message[3]),
            ]));
      }
      callInReceiveNewMessage!();
    });

    connection.on('ReceiveId', (message) {
      myId = message![0];
      debugPrint("client id is $myId");
      connection.invoke('ReceiveFireBaseToken', args: [fireBaseToken]);
      debugPrint("connection status:  ${connection.state}");
      debugPrint("sending token");
      callInReceiveNewMessage!();
    });

    // connection.on('CheckNewClient',(message){
    //   if (_instance.myId != -1){
    //     connection.invoke('getReconnectedUserId', args: []);
    //   }
    // });
  }
}
