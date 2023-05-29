library messaging_signalr;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:messaging_signalr/utils/constants.dart';
import 'package:messaging_signalr/utils/http_requests.dart';
import 'package:messaging_signalr/utils/share_prefs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:signalr_core/signalr_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';

import 'data_base/model_contact.dart';
import 'data_base/model_group.dart';
import 'data_base/model_message.dart';
import 'object_box.dart';
import 'objectbox.g.dart';

/// we have two type of chat private chat and group chat for group chat [name] is null
class Chat {
  Chat({required this.type, required this.chatId, required this.messages, this.image, required this.name});

  ChatType type;
  List<Message> messages = [];

  /// the id of contact or group name based on [type]
  String chatId; // group name for groups and id of contact for private chats
  File? image;

  ///this is just for private chat
  String name;
//may this is good idea to separate this two class check it later
}

///specify type of chat and used in [Chat] class
enum ChatType {
  group,
  contact,
}


typedef OnTasksEnded = void Function(String message);



///this class manage all functionalities and data's
class SignalRMessaging {
  SignalRMessaging._();

  ///this is singleton class
  static final SignalRMessaging _instance = SignalRMessaging._();

  factory SignalRMessaging() => _instance;

  ///the HubConnection will connect to signalr server
  late final HubConnection connection;

  ///list of chats including private and group
  List<Chat> chats = [];

  String? serverAddress;

  ///the token which app receive from firebase messaging package to receive notification
  String? myFireBaseToken;

  /// user name which show to other users
  String? myUserName;
  String? myPhoneNumber;
  String? myPassword;

  File? image;


  late ObjectBox _objectBox;
  late SharedPreferences sp;
  late SharedPrefService _sharedPrefService;

  Box<Message>? messageBox;
  Box<Contact>? contactBox;
  Box<Group>? groupBox;

  ///this function will be called when new message received for example can be use for managing state of the page
  Function? onReceiveNewMessage;

  ///this function will be called when send message
  Function? onSendMessage;

  ///this function will be when receive the information of user which user added to his contacts
  Function? onGetContactInfo;

  ///this function will be called some tasks fails
  OnTasksEnded? onFailure;

  ///this function will be called when successfully connect to server
  Function? onSignUp;

  ///this function will be called when logout function get completed
  Function? onLogout;

  ///this function will be called when login procedure get completed
  Function? onLogin;

  ///after invoking createGroup if task completed successfully
  ///this function will be called the message show that you create this group or the group exists previously
  ///and you join it string show the result of action
  OnTasksEnded? onCreateGroup;

  ///if getting contact info face problem this function will be called and has detail about problem as input
  OnTasksEnded? onGetContactInfoCanceled;

  ///if app disconnected from signalr server This list specifies intervals between efforts to reconnect
  List<int>? delayInterval;

  ///is app received its id from server
  bool connected = false;

  ///is it first time apps try to connect to server?
  bool reconnect = false;

  ///this function have to called before using [SignalRMessaging] singleton class to initiate class


  Future<void> init(
      {
      /// the address of signalr server
      required String serverAddress,

      /// the fire base token receive from fire base messaging will be used to receive notification
      required String firebaseToken,
      required Function onSendMessage,
      required Function onGetContactInfo,
      required Function onReceiveNewMessage,
      required OnTasksEnded onCreateGroup,
      required OnTasksEnded onGetContactInfoCanceled,
        required OnTasksEnded onFailure,
        required Function onSignUp,
        required Function onLogout,
        required Function onLogin
      }) async {

    myFireBaseToken = firebaseToken;

    this.onSendMessage = onSendMessage;
    this.onGetContactInfo = onGetContactInfo;
    this.onReceiveNewMessage = onReceiveNewMessage;
    this.onCreateGroup = onCreateGroup;
    this.onGetContactInfoCanceled = onGetContactInfoCanceled;
    this.onSignUp = onSignUp;
    this.onLogout = onLogout;
    this.onLogin = onLogin;

    this.onFailure = onFailure;

    ConstStrings.baseUrl = serverAddress;

    delayInterval = [];

    //set intervals between efforts to reconnect
    for (int i = 0; i < 1000; i++) {
      delayInterval?.add(1000);
    }



    sp = await SharedPreferences.getInstance();
    _sharedPrefService = SharedPrefService(sp);

    myUserName = _sharedPrefService.getString(SpKeys.username);
    myPhoneNumber = _sharedPrefService.getString(SpKeys.phoneNumber);
    myPassword = _sharedPrefService.getString(SpKeys.password);

    _objectBox = await ObjectBox.create();

    messageBox = _objectBox.store.box<Message>();
    contactBox = _objectBox.store.box<Contact>();
    groupBox = _objectBox.store.box<Group>();

    final contacts = contactBox!.getAll();
    final groups = groupBox!.getAll();

    Directory? directory = await getExternalStorageDirectory();

    for (var contact in contacts) {
      String contactPhone = contact.phoneNumber!;

      final query =
          (messageBox!.query(Message_.senderPhoneNumber.equals(contactPhone) | Message_.receiverId.equals(contactPhone))).build();

      File? imageFile;

      debugPrint("signalr-package: image type is ${contact.imageType}");

      if (contact.imageType != null) {
        debugPrint("signalr-package: path is: ${path.join(directory!.path, "${contact.id}.${contact.imageType}")}");
        imageFile = File(path.join(directory!.path, "${contact.phoneNumber}.${contact.imageType}"));
      } else {
        imageFile = null;
      }

      final result = query.find();

      debugPrint("signalr-package: do we add something here?");

      chats.add(
          Chat(type: ChatType.contact, chatId: contactPhone, name: contact.userName!, messages: result, image: imageFile));
    }

    for (Group group in groups) {
      final query = (messageBox!.query(Message_.receiverId.equals(group.groupID!))).build();

      final result = query.find();

      chats.add(Chat(type: ChatType.group, chatId: group.groupID!, name: group.groupName!, messages: result));
    }

    myFireBaseToken = firebaseToken;

    this.serverAddress = serverAddress;

    connection = HubConnectionBuilder()
        .withUrl(
            "$serverAddress/ChatHub",
            HttpConnectionOptions(
              client: IOClient(HttpClient()..badCertificateCallback = (x, y, z) => true),
              //todo remove bad certificate and and check reconnection
              logging: (level, message) => debugPrint(message),
            ))
        .withAutomaticReconnect(delayInterval)
        .build();

    connection.onclose((exception) {
      connected = false;
    });
    connection.onreconnected((connectionId) {});

    defineSignalrFunctions();
    connection.start()?.then((value){
      debugPrint("even called?");
    });
  }

  ///the function that invoke server side function to send message to a group or a contacts
  Future<void> sendMessage({required bool privateChat, required String message, required String chatId}) async {


    Message storeMessage = Message(
        message: message,
        senderPhoneNumber: myPhoneNumber!,
        receiverId: chatId,
        date: DateTime.now(),
        senderUserName: myUserName!);
    debugPrint("signlar-package: checknull2");
    messageBox!.put(storeMessage);
    debugPrint("signlar-package: sendMessage2");
    Chat targetChat = chats.singleWhere((element) => element.chatId == chatId);

    debugPrint("signalr-package: myUserName is : ${myUserName}");

    targetChat.messages.add(Message(
        senderPhoneNumber: myPhoneNumber!,
        receiverId: chatId,
        message: message,
        senderUserName: myUserName!,
        date: DateTime.now()));

    if (privateChat) {

      connection.invoke('sendMessage', args: [myPhoneNumber ,chatId, message]);
    } else {
      //todo he himself receive message from remote server? i think it should change!
      debugPrint("signalr-package:chat id is: $chatId");
      connection.invoke('SendMessageToGroup', args: [chatId, message, myPhoneNumber]);
    }
    debugPrint("signalr-package: sendMessage3");
    int targetIndex = chats.indexWhere((e) => e.chatId == chatId);
    chats.insert(0, chats[targetIndex]);
    chats.removeAt(targetIndex + 1);
    debugPrint("signalr-package: sendMessage4");
    onSendMessage!();
  }

  ///crete group and join it and if exists just join it
  Future<void> createGroup({required String newGroupName}) async {
    ///we cant join group with same name as a group we previously join
    if (!chats.any((element) => (element.chatId == newGroupName && element.type == ChatType.group))) {
      chats.add(Chat(type: ChatType.group, name: newGroupName, chatId: newGroupName, messages: []));
      connection.invoke('AddToGroup', args: [newGroupName, myPhoneNumber]);
    }
  }

  ///send user name to server and upload user image it has
  Future<void> signUp({File? image, required String userName, required String phoneNumber, required String password}) async {


    if(!connected){

      onFailure!("you are not connected to server");

      return;
    }
    if(image != null){
      this.image = image;
      Future(
          ()async{
           bool success =  await uploadImage(phoneNumber, image);
           if(!success){

           }
          }
      );

    }


      try {

          connection.invoke('signUp', args: [userName, phoneNumber, password, myFireBaseToken]);
      } catch (e) {
        // debugPrint("signalrConnection failed");
      }

      myPhoneNumber = phoneNumber;
      myPassword = password;
      myUserName = userName;


      //todo its better to receive message from server that shows signup completed and then call this function
  }

  ///add new contact and gets its info
  Future<void> addNewContact({required String contactPhoneNumber,}) async {
    debugPrint("signalr-package : add new contact");
    if (contactPhoneNumber == myPhoneNumber) {
      onGetContactInfoCanceled!("you can not create chat with your self");
      return;
    }
    if (!chats.any((element) => element.chatId == contactPhoneNumber.toString())) {
      connection.invoke('newContactInfo', args: [contactPhoneNumber, myPhoneNumber]);
    } else {
      onGetContactInfoCanceled!("this user already is your contact");
    }
  }
  ///logout user and delete his data
  void logout() async{

    ///the logout function should not called before
    messageBox!.removeAll();
    contactBox!.removeAll();
    groupBox!.removeAll();

    String temporaryPhone = myPhoneNumber!;


    _sharedPrefService.setString(SpKeys.phoneNumber, "null");
    _sharedPrefService.setString(SpKeys.password, "null");
    _sharedPrefService.setString(SpKeys.username, "null");

    myPassword = null;
    myUserName = null;
    myPhoneNumber = null;

    chats = [];
    image = null;

    connection.invoke('Logout', args: [temporaryPhone]);

    Directory? directory = await getExternalStorageDirectory();

      //can directory be null?
    directory?.list(recursive: true).listen((file) {
        file.deleteSync();
      });


    onLogout!();

  }

  void login({required String phoneNumber,required String password,required String fireBaseToken}){


    debugPrint("signalr-package connected value is ${connected}");

    if(!connected){

      onFailure!("you are not connected to server");

      return;
    }


    myPhoneNumber = phoneNumber;
    myPassword = password;
    myFireBaseToken = fireBaseToken;

    connection.invoke('Login', args: [phoneNumber ,password, fireBaseToken]);


  }

  ///use to get message between user and his contacts when he open app
  void getMessages(ChatType chatType) {
    for (Chat element in chats) {

      if(element.type == chatType) {
        debugPrint("signalr-package: getMessages");

        if (element.type == ChatType.contact) {
          connection.invoke('getPrivateMessagesFromDataBase', args: [element.chatId, myPhoneNumber]);
        } else {
          connection.invoke('getGroupMessagesFromDataBase', args: [element.chatId]);
        }
      }
    }
  }

  void getImages()async {

    for(Chat element in chats){
      if(element.type == ChatType.contact) {

        final result = await getImageRequest(element.chatId);
        if(result != null) {

          final query =
          (contactBox!.query(Contact_.phoneNumber.equals(element.chatId))).build();

          final queryResult = query.find();

          queryResult.first.imageType = result.item1;

          contactBox!.put(queryResult.first);

          debugPrint("signalr-package: we got image");

          element.image = result.item2;

          onReceiveNewMessage!();

        }
      }
    }

  }

  //call server functions end
  ///define functions which can be called by server
  void defineSignalrFunctions() {
    ///receive new message from server
    connection.on('ReceiveNewMessage', (message) async {
      File? imageFile;
      debugPrint("signalr-package: ReceiveNewMessage");
      final storeMessage = Message(
          message: message![1],
          senderPhoneNumber: message[0],
          receiverId: myPhoneNumber!,
          date: DateTime.now(),
          senderUserName: message[2]);
      messageBox!.put(storeMessage);

      debugPrint("signalr-package: ReceiveNewMessage2");

      int targetIndex = chats.indexWhere((e) => e.chatId == message[0].toString());
      if (targetIndex != -1) {
        chats[targetIndex].messages.add(storeMessage);
        chats.insert(0, chats[targetIndex]);
        chats.removeAt(targetIndex + 1);
      } else {
        //warning you don't there is no phone number in message[3]
        Contact contact = Contact(phoneNumber: message[0], userName: message[2]);


        final result = await getImageRequest(message[0]);


        if(result != null){

          contact.imageType = result.item1;
          imageFile = result.item2;
        }

          contactBox!.put(contact);
          chats.insert(
              0,
              Chat(
                  type: ChatType.contact,
                  chatId: message[0].toString(),
                  messages: [storeMessage],
                  name: message[2],
                  image: imageFile));
      }
      onReceiveNewMessage!();
    });

    ///receive client information

    connection.on('receiveContactInfo', (message) async {

      if (message![0] == "failed") {
        onGetContactInfoCanceled!("there is no contact with this phone number");
        return;
      }

      String userPhone = message![0];
      String userName = message[1];
      debugPrint("signalr-package : receive client info");
      File? imageFile;
      final contact = Contact(userName: userName, phoneNumber: userPhone);

      debugPrint("signalr-package : receive client info1");

      var reqBody = <String, dynamic>{"phoneNumber": userPhone};

      debugPrint("signalr-package : receive client info2");
      var jsonBody = json.encode(reqBody);
      debugPrint("signalr-package : receive client info3");
      try {
        debugPrint("signalr-package: try block 1");
        http.Response response = await http
            .post(
                Uri.parse(
                  "$serverAddress/api/Images/DownloadImage",
                ),
                headers: {"Content-Type": "application/json"},
                body: jsonBody);

        if (response.statusCode == 200) {
          String imageType = response.headers["content-type"]!.split('/')[1];
          contact.imageType = imageType;
          Directory? directory = await getExternalStorageDirectory();
          debugPrint("signalr-package: path is: ${path.join(directory!.path, "$userPhone.$imageType")}");
          imageFile = File(path.join(directory.path, "$userPhone.$imageType"));
          imageFile.writeAsBytes(response.bodyBytes);

          debugPrint("signalr-package:  headers are ${response.headers}");
        } else {
          debugPrint("signalr-package: try block 4");
          debugPrint("signalr-package : getting user image failed. response code is :${response.statusCode}");
        }
      } catch (e) {
        debugPrint("signalr-package: ${e.toString()}");
        debugPrint("signalr-package:getting user image failed with exception");
      }
      contactBox!.put(contact);
      chats.insert(
          0, Chat(type: ChatType.contact, chatId: userPhone, name: userName, messages: [], image: imageFile));

      onGetContactInfo!();
    });

    ///receive new message for group
    connection.on('GroupMessage', (message) {
      int targetIndex = chats.indexWhere((e) => e.chatId == message![0]);
      Message messageStore = Message(
          message: message![2],
          receiverId: message[0],
          senderPhoneNumber: message[1],
          senderUserName: message[3],
          date: DateTime.now());
      messageBox!.put(messageStore);
      if (targetIndex != -1) {
        chats[targetIndex].messages.add(messageStore);
        chats.insert(0, chats[targetIndex]);
        chats.removeAt(targetIndex + 1);
      } else {
        //we shouldn't receive message for group which we are not participate in so i left else blank
      }
      onReceiveNewMessage!();
    });

    connection.on("createGroupResult", (message) {
      debugPrint("signalr-package: createGroupResult called");
      Chat targetChat = chats.firstWhere((element) => element.chatId == message![2]);
      Group group = Group(groupID: message![0], groupName: message[2]);
      groupBox!.put(group);
      targetChat.chatId = message![0];
      if (message[1] == "joined") {
        onCreateGroup!("${message[0]} joined");
      } else {
        onCreateGroup!("${message[0]} created");
      }
    });

    connection.on("signUpResult", (args) {

      debugPrint("signalr-package: signUpResult called");

      if(args![0] == "failed"){

        onFailure!(args[1]);
        myPhoneNumber = null;
        myPassword = null;
        myFireBaseToken = null;

      }else{
        onSignUp!();
        _sharedPrefService.setString(SpKeys.username, myUserName!);
        _sharedPrefService.setString(SpKeys.password, myPassword!);
        _sharedPrefService.setString(SpKeys.phoneNumber, myPhoneNumber!);
      }



    });

    connection.on('LoginResult', (args) {

      debugPrint("signalr-package: in LoginResult");

      if(args![0] == "failed"){
        onFailure!(args[1]);
        myPhoneNumber = null;
        myPassword = null;
        myFireBaseToken = null;

        return;
      }

      debugPrint("signalr-package: in LoginResult1");
      myUserName = args[1];

      _sharedPrefService.setString(SpKeys.password, myPassword!);
      _sharedPrefService.setString(SpKeys.phoneNumber, myPhoneNumber!);
      _sharedPrefService.setString(SpKeys.username, myUserName!);

      onLogin!();


    });

    connection.on('CheckNewClient', (message) {

      debugPrint("signalr-package: checkNewClient");

      connected = true;

      if (myPhoneNumber != null && myPhoneNumber != "null") {
        debugPrint("signalr-package: checkNewClient in if and");
        //todo what to do with reconnect
        connection.invoke('oldClient', args: [myPhoneNumber]);
        reconnect = true;
      }
    });

    ///receive info of Chats( whether private or group) previously added to contact by user
    connection.on('ReceiveChatsInfo', (message) {

      debugPrint("signalr-package: ReceiveChatsInfo $message");

      List ids = [];
      List chatName = [];
      ChatType type = message![1] == 1 ? ChatType.contact : ChatType.group;
      for (var v in message[0].keys) {
        ids.add(v);
      }
      for (var v in message[0].values) {
        chatName.add(v);
      }
      for (int i = 0; i < ids.length; i++) {
        chats.add(Chat(type: type, chatId: ids[i], name: chatName[i], messages: []));

        if(type == ChatType.contact){
          Contact newContact = Contact(userName: chatName[i], phoneNumber: ids[i]);
          contactBox!.put(newContact);
        }else{
          Group newGroup = Group(groupName: chatName[i],groupID: ids[i]);
          groupBox!.put(newGroup);
        }
      }
      onReceiveNewMessage!();
      getMessages(type);
      if(type == ChatType.contact){
        getImages();
      }

    });

    ///receive old message from server
    connection.on('receiveMessages', (args) {
      Chat chat = chats.singleWhere((element) => (element.chatId == args![0]));

      debugPrint("signalr-package : receiveMessages ${args![1]}");

      for (int i = 0; i < args![1].length; i++) {

        debugPrint("signalr-package : receiveMessages in loop");

        var newFormatDate = args[1][i]['date'].replaceAll("T", ' ');

        DateTime messageDate = DateTime.parse(newFormatDate);

        Message newMessage = Message(
            senderPhoneNumber: args[1][i]['senderId'],
            receiverId: args[1][i]['receiverId'],
            message: args[1][i]['message'],
            senderUserName: args[2] == "group" ? args[3][i] : chat.name,
            date: messageDate);

        chat.messages.add(newMessage);

        messageBox!.put(newMessage);
      }

      onReceiveNewMessage!();

      //connection.invoke('receiveRest');
    });
  }
}
