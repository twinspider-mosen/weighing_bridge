import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  // static StreamSubscription stream = FirebaseFirestore.instance.collection("record").snapshots();

  static Stream getCommandStream({
    required String scaleName,
    required List<String> subdomains,
  }) {
    if (scaleName.isEmpty || subdomains.isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('ScaleRequests')
        .where('scale_name', isEqualTo: scaleName)
        .where('subdomain', whereIn: subdomains)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .snapshots();
  }
}
