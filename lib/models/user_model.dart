import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phoneNumber;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phoneNumber,
  });

  // Factory constructor for Firestore mapping
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? 'Passenger',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
    );
  }

  // Create Map for Firestore uploads
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
