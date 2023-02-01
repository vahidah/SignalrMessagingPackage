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
  String chatId;// group name for groups and id of contact for private chats
  String? image;
  String? userName;//this is just for private chat
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

  static void init({required String serverAddress, required String firebaseToken, required bool haveImage, required Function eventCall}){
    instance.connection = HubConnectionBuilder()
        .withUrl(
        serverAddress,
        HttpConnectionOptions(
          client: IOClient(HttpClient()
            ..badCertificateCallback = (x, y, z) => true),
          //todo remove bad certificate and and check reconnection
          logging: (level, message) => debugPrint(message),
        ))
        .build();
    instance.haveImage = haveImage;
    instance.fireBaseToken = firebaseToken;
    instance.callInReceiveNewMessage = eventCall;
    instance.defineSignalrFunctions();
    instance.connection.start();
  }

  List<Chat> chats = [];

  int myId = -1;
  String? fireBaseToken;
  bool? haveImage;
  String? userName;
  File? image;

  Function? callInReceiveNewMessage;

  Chat? selectedChat;

  void setSelectedChat(String chatKey) {
    selectedChat = chats.firstWhere((element) {
      debugPrint("chatkey is : chatKey and element key is : ${element.chatId}");
      return element.chatId == chatKey;
    });
  }

  SignalRMessaging._();

  static final SignalRMessaging instance = SignalRMessaging._();


  late final HubConnection connection;

  //call server functions


  Future<void> sendMessage({required bool privateChat, required String message}) async{
    if (privateChat) {
      selectedChat!.messages.add(
          Message(sender: myId, text: message, senderUserName: userName!));
      connection.invoke(
          'sendMessage', args: [int.parse(selectedChat!.chatId), message, false]);
    } else {
      connection.invoke('SendMessageToGroup', args: [selectedChat!.chatId, myId, message]);
    }
    callInReceiveNewMessage!();
  }


  void createGroup({required String newGroupName}) {
    if (!chats.any((element) => element.chatId == newGroupName)) {
      chats.add(Chat(type: ChatType.group, chatId: newGroupName, messages: []));
      connection.invoke('AddToGroup', args: [newGroupName]);
      callInReceiveNewMessage!();
    }
  }

  Future<void> sendContactName({required File image, required String userName }) async {
    Dio dio = Dio();
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
    final response = await dio
        .post("http://10.0.2.2:5003/api/Image",
        data: map,
        options: Options(
          sendTimeout: 2000,
          receiveTimeout: 2000,
        ));

    debugPrint("status code is ${response.statusCode}");

    if (response.statusCode == 200) {
      debugPrint("successfully upload image");
    } else {
      debugPrint("upload image failed response from server gotten");
    }

    debugPrint("before upload image");
    debugPrint("after upload image");
    this.userName = userName;
    debugPrint("sending user name $userName}");
    connection.invoke('ReceiveUserName', args: [this.userName, myId]);

    // signalRMessaging.setUserName(userNameIn)
  }

  void sendFirstMessage(int contactId, String firstMessage) async {
    String? base64Image;

    http.Response response = await http.post(
      Uri.parse(
        "${"http://10.0.2.2:5003/api/Image"}/$contactId",
      ),
    );

    if (response.statusCode == 200) {
      base64Image = base64.encode(response.bodyBytes);
    } else {
      debugPrint("get image failed");
    }

    chats.insert(
        0,
        Chat(
            type: ChatType.contact,
            chatId: contactId.toString(),
            messages: [
              Message(sender: myId, text: firstMessage, senderUserName: userName!)
            ],
            image: base64Image));
    connection.invoke('sendMessage',
        args: [contactId, firstMessage, true]);

    debugPrint("newContactController 2");
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
        debugPrint("new message received 4");
        if (haveImage!) {
          debugPrint("send request to get image");
          Map<String, String> requestHeaders = {
            "Connection": "keep-alive",
          };
          http.Response response = await http.post(
              Uri.parse(
                "http://10.0.2.2:5003/api/Image/${message![0]}",
              ),
              headers: requestHeaders);
          debugPrint("image received");
          base64Image = base64.encode(response.bodyBytes);
        }

        debugPrint("image received");
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
      debugPrint("new message received 5");
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
  }
}
