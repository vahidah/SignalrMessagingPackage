import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:messaging_signalr/messaging_signalr.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  SignalRMessaging signalRMessaging = SignalRMessaging();
  
  @override
  void initState() {

    SignalRMessaging.init(
      eventCall: () => setState(() {}),
      firebaseToken: "",
      serverAddress: "your signalr Server Address",
    );
    super.initState();
  }
  
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
        home: Scaffold(
          appBar: AppBar(title: const Text("example for usage of messaging_signalr"),
            leading: Text("My Id is: ${signalRMessaging.myId}"),
          ),
          body: ListView(
            children: [
              ...signalRMessaging.chats.map((e) => Container(
                height: 60,
                decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            width: 1.0, color: Colors.black, style: BorderStyle.solid))),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: CircleAvatar(
                        backgroundImage: e.image != null
                            ? MemoryImage(base64.decode(e.image!))
                            : const AssetImage("assets/images/4.jpg") as ImageProvider,
                        radius: 25,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              e.userName ?? e.chatId,
                              style: const TextStyle(
                                  fontSize: 27, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ),
                          Text(
                            e.messages.isNotEmpty
                                ? "${e.messages[0].senderUserName} : ${e.messages[0].text}"
                                : "",
                            style: const TextStyle(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              e.messages.isNotEmpty?
                              "${e.messages[0].date?.hour}: ${e.messages[0].date?.minute}"
                                  : "",
                              style: const TextStyle(color:Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ))
            ],
          ),
        ),
    );
  }
}