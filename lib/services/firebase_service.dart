import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  // static StreamSubscription stream = FirebaseFirestore.instance.collection("record").snapshots();

  static Stream getCommandStream({required String scaleID,required  List<String> subdomains}) {
    return FirebaseFirestore.instance
        .collection('ScaleRequests')
        .where('scale_id', isEqualTo: scaleID)
        .where('subdomain', whereIn: subdomains)
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .limit(1)
        .snapshots();
  }
//   static Future<void> addNewEntry()async{
//     try {
      
    
//     await FirebaseFirestore.instance.collection('commands').add({
//       'created_at': DateTime.now().millisecondsSinceEpoch,
//       'request_id': DateTime.now().millisecondsSinceEpoch.toString(),
//       'scale_id'
// :'scale_1', 'status':'pending',
// 'subdomain': 'imran'    });

//   print('new entry added!');
// } catch (e) {
//       throw Exception(e);
//     }
  // }
}
