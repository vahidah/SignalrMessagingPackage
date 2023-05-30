import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';

import 'constants.dart';

Future<Tuple2<String?, File?>?> getImageRequest(String userPhone, Directory directory) async {
  File? imageFile;

  try {
    var reqBody = <String, dynamic>{"phoneNumber": userPhone};

    var jsonBody = json.encode(reqBody);
    var response = await http.post(
      Uri.parse(
        "${ConstStrings.baseUrl}/api/Images/DownloadImage",
      ),
      headers: {"Content-Type": "application/json"},
      body: jsonBody,
    );
    // var response = await http
    //     .post(
    //   Uri.parse(
    //     "${ConstStrings.baseUrl}/api/Images/DownloadImage",
    //   ),
    //   headers: {"Content-Type": "application/json"},
    //   body: jsonBody,
    // )
    //     .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      String imageType = response.headers["content-type"]!.split('/')[1];
      // contact.imageType = imageType;

      imageFile = File(path.join(directory!.path, "${userPhone}.${imageType}"));
      imageFile.writeAsBytes(response.bodyBytes);

      return Tuple2(imageType, imageFile);
    }

    //   Dio dio = Dio();
    //
    //   dio.options.headers['content-Type'] = 'application/json';
    //
    //   final response = await dio.post("${ConstStrings.baseUrl}/api/Images/UploadImage", data: jsonBody);
    //   if(response.statusCode == 200){
    //
    //     debugPrint("signalr-package: no problem with dio ${response.statusCode}");
    //
    // }
    else {
      debugPrint("signalr-package: ReceiveNewMessage user have no image response code ${response.statusCode}");
    }
  } catch (e) {
    debugPrint("error catched: ${e.toString()}");
  }
}

Future<bool> uploadImage(String userPhone, File image, ) async {

  try {
    BaseOptions options = BaseOptions(
        receiveDataWhenStatusError: true,
        connectTimeout: const Duration(milliseconds: 5 * 1000), // 60 seconds
        receiveTimeout: const Duration(milliseconds: 5 * 1000) // 60 seconds
    );

    Dio dio = Dio(options);
    //todo make structure for package and move http request from here and check exceptions
    // (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (HttpClient client) {
    //   client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    //   return client;
    // };

    FormData map = FormData.fromMap({
      "file": await MultipartFile.fromFile(image.path, filename: image.path
          .split('/')
          .last),
      "phoneNumber": userPhone
    });

    final response = await dio.post("${ConstStrings.baseUrl}/api/Images/UploadImage", data: map);

    if (response.statusCode == 200) {
      debugPrint("signalr_package:successfully upload image");
      return true;
    } else {
      debugPrint("signalr_package: upload image failed response from server gotten");
      return false;
    }
  }catch(exception){
    return false;
  }
}
