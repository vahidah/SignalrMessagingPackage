<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

# messaging_signalr

## Introduction

Package hold and manage all data's and functions needed for Messaging application using signalr

## Usage
```yaml
dependencies:
  messaging_signalr: 1.0.0
```

```dart
import 'package:messaging_signalr/messaging_signalr.dart';
```

###Initializing

In the first step you must call init function before use package features. In init function you have
to configure server address and pass the the fireBase token you have received from FirebaseMessaging
(see [firebase_messaging package](https://pub.dev/documentation/google_fonts/latest/google_fonts/GoogleFonts/config.html))
then you have to pass some call back function to it which will be called when a task fails or succeeds.

```dart
  SignalRMessaging.init(
      serverAddress: 'http://167.235.239.170:5025/Myhub',
      firebaseToken: ConstValues.fireBaseToken,
      onSendMessage: (){},// will be called when sending message to contact or group has done
      onGetContactInfo: (){},/* when you invoke addNewContact method after After receiving contact info completed this method will
      be called  */
      onGetContactInfoCanceled: (String message){},//if getting contact info faces problem and fails this
      method will be called the string shows the reason of failure
      onCreateGroup: (String message){}/* after invoking createGroup if task completed successfully
      this function will be called the message show that you create this group or the group exists previously
      and you join it string show the result of action */
  );
```
## Usage

you have access to chats which is list of all groups and contact you have chatted with them include their
information and exchanged Messages

see example:

```dart

ListView(
          children: [
            ...signalRMessaging.chats.map((e) {
              return Container(
                height: 65,
                decoration: const BoxDecoration(
                    border: Border(
                        bottom:
                        BorderSide(width: 1.0, color: Colors.black, style: BorderStyle.solid))),
                child: Row(
                  children: [
                    Container(
                        margin: const EdgeInsets.only(right: 8.0, left: 8.0, bottom: 8.0),
                        padding: const EdgeInsets.all(10),
                        height: 60,
                        width: 60,
                        decoration:
                        BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(30)
                          //more than 50% of width makes circle
                        ),
                        child: FittedBox(
                          fit: BoxFit.fitWidth,
                          child: Text(
                            firstTwoChOfName(e.userName ?? e.chatId),
                            style: const TextStyle(color: ProjectColors.fontWhite),
                          ),
                        )),
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
                                ? "${e.messages.last.senderUserName} : ${e.messages.last.text}"
                                : e.type == ChatType.contact ? "say hi to ${e.userName}!" : "say hi to all!",
                            style: const TextStyle(
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList()
          ],
        )
```


See full example

## Additional information

this package is private and is not useful for everyone
