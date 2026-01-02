// user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String username;
  final DateTime createdAt;
  final List<String> friends;
  final List<String> groups;

  AppUser({
    required this.id,
    required this.username,
    required this.createdAt,
    required this.friends,
    required this.groups,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return AppUser(
      id: doc.id,
      username: data['username'],
      createdAt: data['createdAt'].toDate(),
      friends: List<String>.from(data['friends']),
      groups: List<String>.from(data['groups']),
    );
  }
}
