import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:suggest_it/services/logging_service.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppLogger _logger = AppLogger();

  // User operations - create user document on first login
  Future<void> createUserDocument(User user) async {
    try {
      _logger.firebase(
        'get user document',
        collection: 'users',
        documentId: user.uid,
      );

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        _logger.i('Creating new user document for ${user.uid}', tag: 'USER');

        final userData = {
          'createdAt': FieldValue.serverTimestamp(),
          'friends': [],
          'groups': [],
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'lastLogin': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('users').doc(user.uid).set(userData);

        _logger.firebase(
          'create user document',
          collection: 'users',
          documentId: user.uid,
          data: {'email': user.email, 'displayName': user.displayName},
        );
      } else {
        _logger.i('Updating last login for user ${user.uid}', tag: 'USER');

        await _firestore.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });

        _logger.firebase(
          'update user document',
          collection: 'users',
          documentId: user.uid,
          data: {'lastLogin': 'updated'},
        );
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to create/update user document for ${user.uid}',
        error: e,
        stackTrace: stackTrace,
        tag: 'USER',
      );
      rethrow;
    }
  }

  // Group operations
  Future<String> createGroup(
    String name,
    List<dynamic> members,
    String createdBy,
  ) async {
    _logger.userAction(
      'create group',
      userId: createdBy,
      metadata: {'name': name, 'memberCount': members.length},
    );

    // Ensure at least 2 members
    if (members.length < 2) {
      final error = Exception('A group must have at least 2 members');
      _logger.e(
        'Group creation failed: insufficient members',
        error: error,
        tag: 'GROUPS',
      );
      throw error;
    }

    try {
      _logger.i(
        'Creating group "$name" with ${members.length} members',
        tag: 'GROUPS',
      );

      final doc = await _firestore.collection('groups').add({
        'name': name,
        'members': members,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final groupId = doc.id;

      _logger.firebase(
        'create group',
        collection: 'groups',
        documentId: groupId,
        data: {'name': name, 'members': members.length},
      );

      // Add group ID to each member's groups array
      final batch = _firestore.batch();
      for (final memberId in members) {
        final userRef = _firestore.collection('users').doc(memberId);
        batch.update(userRef, {
          'groups': FieldValue.arrayUnion([groupId]),
        });
      }

      await batch.commit();

      _logger.i(
        'Group "$name" created successfully with ID: $groupId',
        tag: 'GROUPS',
      );
      _logger.userAction(
        'group created',
        userId: createdBy,
        metadata: {'groupId': groupId, 'name': name},
      );

      return groupId;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to create group "$name"',
        error: e,
        stackTrace: stackTrace,
        tag: 'GROUPS',
      );
      rethrow;
    }
  }

  // Suggestion operations
  Future<void> addSuggestion(String groupId, String text, String userId) async {
    _logger.userAction(
      'add suggestion',
      userId: userId,
      metadata: {
        'groupId': groupId,
        'textPreview': text.length > 50 ? '${text.substring(0, 50)}...' : text,
      },
    );

    try {
      await _firestore.collection('suggestions').add({
        'text': text,
        'createdBy': userId,
        'groupId': groupId,
        'createdAt': FieldValue.serverTimestamp(),
        'votes': {},
        'status': 'pending',
      });

      _logger.i(
        'Suggestion added to group $groupId by user $userId',
        tag: 'SUGGESTIONS',
      );
      _logger.firebase(
        'create suggestion',
        collection: 'suggestions',
        data: {'groupId': groupId, 'userId': userId},
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to add suggestion to group $groupId',
        error: e,
        stackTrace: stackTrace,
        tag: 'SUGGESTIONS',
      );
      rethrow;
    }
  }

  // Get group stream
  Stream<DocumentSnapshot<Map<String, dynamic>>> getGroupStream(String groupId) {
    _logger.d('Getting group stream for $groupId', tag: 'GROUPS');
    
    return _firestore
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .handleError((error, stackTrace) {
          _logger.e(
            'Failed to fetch group stream for $groupId',
            error: error,
            stackTrace: stackTrace,
            tag: 'GROUPS',
          );
          throw FirebaseException(
            plugin: 'flutterfire',
            message: 'Failed to fetch group: ${error.toString()}',
          );
        });
  }

  // Get suggestions for a specific group
  Stream<QuerySnapshot<Map<String, dynamic>>> getGroupSuggestionsStream(String groupId) {
    _logger.d('Getting suggestions stream for group $groupId', tag: 'SUGGESTIONS');
    
    return _firestore
        .collection('suggestions')
        .where('groupId', isEqualTo: groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error, stackTrace) {
          _logger.e(
            'Failed to fetch group suggestions stream for $groupId',
            error: error,
            stackTrace: stackTrace,
            tag: 'SUGGESTIONS',
          );
          throw FirebaseException(
            plugin: 'flutterfire',
            message: 'Failed to fetch suggestions: ${error.toString()}',
          );
        });
  }

  // Get accepted suggestions stream (for top display)
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> getAcceptedSuggestionsStream(List<String> groupIds) {
    _logger.d('Getting accepted suggestions for ${groupIds.length} groups', tag: 'SUGGESTIONS');
    
    if (groupIds.isEmpty) {
      return const Stream.empty();
    }
    
    if (groupIds.length <= 10) {
      return _firestore
          .collection('suggestions')
          .where('groupId', whereIn: groupIds)
          .where('status', isEqualTo: 'accepted')
          .where('acceptedAt', isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 7))
          ))
          .orderBy('acceptedAt', descending: true)
          .snapshots()
          .map((querySnapshot) => querySnapshot.docs)
          .handleError((error, stackTrace) {
            _logger.e(
              'Failed to fetch accepted suggestions stream',
              error: error,
              stackTrace: stackTrace,
              tag: 'SUGGESTIONS',
            );
            throw FirebaseException(
              plugin: 'flutterfire',
              message: 'Failed to fetch accepted suggestions: ${error.toString()}',
            );
          });
    } else {
      // For more than 10 groups, use multiple queries
      return _getAcceptedSuggestionsUsingMultipleStreams(groupIds);
    }
  }

  // Get pending suggestions stream
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> getPendingSuggestionsStream(List<String> groupIds) {
    _logger.d('Getting pending suggestions for ${groupIds.length} groups', tag: 'SUGGESTIONS');
    
    if (groupIds.isEmpty) {
      return const Stream.empty();
    }
    
    if (groupIds.length <= 10) {
      return _firestore
          .collection('suggestions')
          .where('groupId', whereIn: groupIds)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((querySnapshot) => querySnapshot.docs)
          .handleError((error, stackTrace) {
            _logger.e(
              'Failed to fetch pending suggestions stream',
              error: error,
              stackTrace: stackTrace,
              tag: 'SUGGESTIONS',
            );
            throw FirebaseException(
              plugin: 'flutterfire',
              message: 'Failed to fetch pending suggestions: ${error.toString()}',
            );
          });
    } else {
      // For more than 10 groups, use multiple queries
      return _getPendingSuggestionsUsingMultipleStreams(groupIds);
    }
  }

  // Get suggestions stream for home page (backward compatibility)
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> getSuggestionsStream(
    List<String> groupIds,
  ) {
    _logger.d(
      'Getting suggestions stream for ${groupIds.length} groups',
      tag: 'SUGGESTIONS',
    );

    if (groupIds.isEmpty) {
      _logger.w(
        'No group IDs provided for suggestions stream',
        tag: 'SUGGESTIONS',
      );
      return const Stream.empty();
    }

    // Option 1: Use whereIn for a single query (most efficient)
    // NOTE: whereIn has a limit of 10 values in Firestore
    if (groupIds.length <= 10) {
      return _getSuggestionsUsingWhereIn(groupIds);
    } else {
      // Option 2: For more than 10 groups, use multiple queries and combine
      return _getSuggestionsUsingMultipleStreams(groupIds);
    }
  }

  // Method 1: Single query using whereIn (more efficient)
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>>
  _getSuggestionsUsingWhereIn(List<String> groupIds) {
    _logger.v(
      'Using whereIn for ${groupIds.length} groups',
      tag: 'SUGGESTIONS',
    );

    return _firestore
        .collection('suggestions')
        .where('groupId', whereIn: groupIds)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((querySnapshot) {
          _logger.d(
            'Received ${querySnapshot.docs.length} suggestions from whereIn query',
            tag: 'SUGGESTIONS',
          );
          return querySnapshot.docs;
        })
        .handleError((error, stackTrace) {
          _logger.e(
            'Failed to fetch suggestions stream using whereIn',
            error: error,
            stackTrace: stackTrace,
            tag: 'SUGGESTIONS',
          );
          throw FirebaseException(
            plugin: 'flutterfire',
            message: 'Failed to fetch suggestions: ${error.toString()}',
          );
        });
  }

  // Method 2: Multiple queries for when there are more than 10 groups
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>>
  _getSuggestionsUsingMultipleStreams(List<String> groupIds) {
    _logger.v(
      'Using multiple streams for ${groupIds.length} groups',
      tag: 'SUGGESTIONS',
    );

    // Create individual streams for each group
    final streams = <Stream<QuerySnapshot<Map<String, dynamic>>>>[];

    for (final groupId in groupIds) {
      _logger.v('Creating stream for group $groupId', tag: 'SUGGESTIONS');

      final stream = _firestore
          .collection('suggestions')
          .where('groupId', isEqualTo: groupId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots();

      streams.add(stream);
    }

    // Create a stream controller to manage the combined stream
    final controller =
        StreamController<List<DocumentSnapshot<Map<String, dynamic>>>>();

    // Map to store the latest snapshot for each group
    final Map<String, List<DocumentSnapshot<Map<String, dynamic>>>> groupDocs =
        {};

    // Function to combine all docs and add to controller
    void emitCombinedDocs() {
      final allDocs = <DocumentSnapshot<Map<String, dynamic>>>[];

      // Collect all documents from all groups
      for (final docs in groupDocs.values) {
        allDocs.addAll(docs);
      }

      _logger.d(
        'Combined ${allDocs.length} suggestions from ${groupDocs.length} groups',
        tag: 'SUGGESTIONS',
      );

      // Sort by createdAt descending
      allDocs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aDate = aData?['createdAt'] as Timestamp?;
        final bDate = bData?['createdAt'] as Timestamp?;

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate);
      });

      // Add to controller if it hasn't been closed
      if (!controller.isClosed) {
        controller.add(allDocs);
      }
    }

    // Listen to each stream
    final subscriptions = <StreamSubscription>[];

    for (int i = 0; i < groupIds.length; i++) {
      final groupId = groupIds[i];
      final subscription = streams[i].listen(
        (querySnapshot) {
          // Update the documents for this group
          groupDocs[groupId] = querySnapshot.docs;
          // Emit the combined documents
          emitCombinedDocs();
        },
        onError: (error) {
          _logger.e(
            'Error in stream for group $groupId',
            error: error,
            tag: 'SUGGESTIONS',
          );

          if (!controller.isClosed) {
            controller.addError(error);
          }
        },
      );

      subscriptions.add(subscription);
    }

    // Set up cleanup when the controller is closed
    controller.onCancel = () {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    };

    return controller.stream;
  }

  // Method for multiple streams for accepted suggestions
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> _getAcceptedSuggestionsUsingMultipleStreams(
    List<String> groupIds
  ) {
    _logger.v('Using multiple streams for accepted suggestions in ${groupIds.length} groups', 
      tag: 'SUGGESTIONS');

    final streams = <Stream<List<DocumentSnapshot<Map<String, dynamic>>>>>[];
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));

    for (final groupId in groupIds) {
      final stream = _firestore
          .collection('suggestions')
          .where('groupId', isEqualTo: groupId)
          .where('status', isEqualTo: 'accepted')
          .where('acceptedAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .orderBy('acceptedAt', descending: true)
          .snapshots()
          .map((querySnapshot) => querySnapshot.docs);

      streams.add(stream);
    }

    return _combineMultipleListsStreams(streams, 'acceptedAt');
  }

  // Method for multiple streams for pending suggestions
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> _getPendingSuggestionsUsingMultipleStreams(
    List<String> groupIds
  ) {
    _logger.v('Using multiple streams for pending suggestions in ${groupIds.length} groups', 
      tag: 'SUGGESTIONS');

    final streams = <Stream<List<DocumentSnapshot<Map<String, dynamic>>>>>[];

    for (final groupId in groupIds) {
      final stream = _firestore
          .collection('suggestions')
          .where('groupId', isEqualTo: groupId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((querySnapshot) => querySnapshot.docs);

      streams.add(stream);
    }

    return _combineMultipleListsStreams(streams, 'createdAt');
  }

  // Helper to combine multiple list streams
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> _combineMultipleListsStreams(
    List<Stream<List<DocumentSnapshot<Map<String, dynamic>>>>> streams,
    String sortField
  ) {
    final controller = StreamController<List<DocumentSnapshot<Map<String, dynamic>>>>();
    final subscriptions = <StreamSubscription>[];
    final allDocs = <DocumentSnapshot<Map<String, dynamic>>>[];

    void emitCombinedDocs() {
      // Sort by appropriate field
      allDocs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aDate = aData?[sortField] as Timestamp?;
        final bDate = bData?[sortField] as Timestamp?;

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate); // Descending
      });

      if (!controller.isClosed) {
        controller.add(List.from(allDocs));
      }
    }

    for (final stream in streams) {
      final subscription = stream.listen(
        (newDocs) {
          // Replace docs from the same group
          if (newDocs.isNotEmpty) {
            final firstDoc = newDocs.first;
            final firstDocData = firstDoc.data();
            final groupId = firstDocData?['groupId'];
            
            // Remove old docs from this group
            allDocs.removeWhere((doc) {
              final docData = doc.data();
              return docData?['groupId'] == groupId;
            });
            
            // Add new docs
            allDocs.addAll(newDocs);
            emitCombinedDocs();
          }
        },
        onError: (error) {
          _logger.e('Error in combined stream', error: error, tag: 'SUGGESTIONS');
          if (!controller.isClosed) {
            controller.addError(error);
          }
        },
      );

      subscriptions.add(subscription);
    }

    controller.onCancel = () {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    };

    return controller.stream;
  }

  // Get user document
  Future<DocumentSnapshot> getUserDocument(String uid) async {
    try {
      _logger.v('Getting user document for $uid', tag: 'USER');
      return await _firestore.collection('users').doc(uid).get();
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to get user document for $uid',
        error: e,
        stackTrace: stackTrace,
        tag: 'USER',
      );
      rethrow;
    }
  }

  // Search users by email
  Future<List<DocumentSnapshot>> searchUsersByEmail(String emailQuery) async {
    _logger.userAction('search users', metadata: {'query': emailQuery});

    try {
      _logger.d('Searching users with email query: $emailQuery', tag: 'USER');

      final snapshot = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: emailQuery)
          .where('email', isLessThan: '${emailQuery}z')
          .limit(10)
          .get();

      _logger.i(
        'Found ${snapshot.docs.length} users matching "$emailQuery"',
        tag: 'USER',
      );
      return snapshot.docs;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to search users with query: $emailQuery',
        error: e,
        stackTrace: stackTrace,
        tag: 'USER',
      );
      rethrow;
    }
  }

  // Add friend
  Future<void> addFriend(String userId, String friendId) async {
    _logger.userAction(
      'add friend',
      userId: userId,
      metadata: {'friendId': friendId},
    );

    try {
      _logger.i('Adding friend $friendId to user $userId', tag: 'FRIENDS');

      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(userId);
      final friendRef = _firestore.collection('users').doc(friendId);

      batch.update(userRef, {
        'friends': FieldValue.arrayUnion([friendId]),
      });

      batch.update(friendRef, {
        'friends': FieldValue.arrayUnion([userId]),
      });

      await batch.commit();

      _logger.i(
        'Successfully added friend $friendId to user $userId',
        tag: 'FRIENDS',
      );
      _logger.firebase(
        'update friend lists',
        collection: 'users',
        data: {'userId': userId, 'friendId': friendId},
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to add friend $friendId to user $userId',
        error: e,
        stackTrace: stackTrace,
        tag: 'FRIENDS',
      );
      rethrow;
    }
  }

  // Remove friend
  Future<void> removeFriend(String userId, String friendId) async {
    _logger.userAction(
      'remove friend',
      userId: userId,
      metadata: {'friendId': friendId},
    );

    try {
      _logger.i('Removing friend $friendId from user $userId', tag: 'FRIENDS');

      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(userId);
      final friendRef = _firestore.collection('users').doc(friendId);

      batch.update(userRef, {
        'friends': FieldValue.arrayRemove([friendId]),
      });

      batch.update(friendRef, {
        'friends': FieldValue.arrayRemove([userId]),
      });

      await batch.commit();

      _logger.i(
        'Successfully removed friend $friendId from user $userId',
        tag: 'FRIENDS',
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to remove friend $friendId from user $userId',
        error: e,
        stackTrace: stackTrace,
        tag: 'FRIENDS',
      );
      rethrow;
    }
  }

  // Get user's friends
  Future<List<DocumentSnapshot>> getUserFriends(String userId) async {
    try {
      _logger.v('Getting friends for user $userId', tag: 'FRIENDS');

      final userDoc = await getUserDocument(userId);
      if (!userDoc.exists) {
        _logger.w('User document not found for $userId', tag: 'FRIENDS');
        return [];
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final friendIds = List<String>.from(userData['friends'] ?? []);

      _logger.d('User $userId has ${friendIds.length} friends', tag: 'FRIENDS');

      if (friendIds.isEmpty) {
        return [];
      }

      final friendsSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: friendIds)
          .get();

      _logger.i(
        'Retrieved ${friendsSnapshot.docs.length} friend documents for user $userId',
        tag: 'FRIENDS',
      );
      return friendsSnapshot.docs;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to get friends for user $userId',
        error: e,
        stackTrace: stackTrace,
        tag: 'FRIENDS',
      );
      rethrow;
    }
  }

  // Get user's groups
  Future<List<DocumentSnapshot>> getUserGroups(String userId) async {
    try {
      _logger.v('Getting groups for user $userId', tag: 'GROUPS');

      final userDoc = await getUserDocument(userId);
      if (!userDoc.exists) {
        _logger.w('User document not found for $userId', tag: 'GROUPS');
        return [];
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final groupIds = List<String>.from(userData['groups'] ?? []);

      _logger.d('User $userId is in ${groupIds.length} groups', tag: 'GROUPS');

      if (groupIds.isEmpty) {
        return [];
      }

      final groupsSnapshot = await _firestore
          .collection('groups')
          .where(FieldPath.documentId, whereIn: groupIds)
          .get();

      _logger.i(
        'Retrieved ${groupsSnapshot.docs.length} group documents for user $userId',
        tag: 'GROUPS',
      );
      return groupsSnapshot.docs;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to get groups for user $userId',
        error: e,
        stackTrace: stackTrace,
        tag: 'GROUPS',
      );
      rethrow;
    }
  }

  // Updated voteOnSuggestion method to handle automatic acceptance
  Future<void> voteOnSuggestion(
    String suggestionId,
    String userId,
    bool vote,
  ) async {
    _logger.userAction(
      'vote on suggestion',
      userId: userId,
      metadata: {'suggestionId': suggestionId, 'vote': vote},
    );

    try {
      _logger.i(
        'User $userId voting $vote on suggestion $suggestionId',
        tag: 'SUGGESTIONS',
      );

      // Get the current suggestion to check votes and group info
      final suggestionDoc = await _firestore
          .collection('suggestions')
          .doc(suggestionId)
          .get();

      if (!suggestionDoc.exists) {
        throw Exception('Suggestion not found');
      }

      final suggestionData = suggestionDoc.data() as Map<String, dynamic>;
      final groupId = suggestionData['groupId'];
      final currentStatus = suggestionData['status'] as String? ?? 'pending';

      // No voting on accepted suggestions
      if (currentStatus == 'accepted') {
        throw Exception('Cannot vote on accepted suggestions');
      }

      // Get group info to know total members
      final groupDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) {
        throw Exception('Group not found');
      }

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final members = List<String>.from(groupData['members'] ?? []);
      final totalMembers = members.length;

      // Update the vote
      await _firestore.collection('suggestions').doc(suggestionId).update({
        'votes.$userId': vote,
      });

      // Get updated votes to check if majority agrees
      final updatedDoc = await _firestore
          .collection('suggestions')
          .doc(suggestionId)
          .get();
      
      final updatedData = updatedDoc.data() as Map<String, dynamic>;
      final votes = updatedData['votes'] as Map<String, dynamic>? ?? {};
      final agreedCount = votes.values.where((v) => v == true).length;

      // Check if majority agrees (> 50%)
      if (agreedCount > totalMembers / 2) {
        // Mark as accepted
        await _firestore.collection('suggestions').doc(suggestionId).update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        _logger.i(
          'Suggestion $suggestionId accepted by majority ($agreedCount/$totalMembers)',
          tag: 'SUGGESTIONS',
        );
        
        _logger.firebase(
          'suggestion accepted',
          collection: 'suggestions',
          documentId: suggestionId,
          data: {
            'groupId': groupId,
            'agreedCount': agreedCount,
            'totalMembers': totalMembers
          },
        );
      }

      _logger.firebase(
        'update suggestion vote',
        collection: 'suggestions',
        documentId: suggestionId,
        data: {'userId': userId, 'vote': vote},
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to vote on suggestion $suggestionId',
        error: e,
        stackTrace: stackTrace,
        tag: 'SUGGESTIONS',
      );
      rethrow;
    }
  }


// Update suggestion status
Future<void> updateSuggestionStatus(
  String suggestionId,
  String status,
) async {
  try {
    _logger.i(
      'Updating suggestion $suggestionId status to $status',
      tag: 'SUGGESTIONS',
    );

    final updateData = <String, dynamic>{'status': status};
    
    // If accepting, add acceptedAt timestamp
    if (status == 'accepted') {
      updateData['acceptedAt'] = FieldValue.serverTimestamp();
    }

    await _firestore.collection('suggestions').doc(suggestionId).update(updateData);

    _logger.firebase(
      'update suggestion status',
      collection: 'suggestions',
      documentId: suggestionId,
      data: {'status': status},
    );
  } catch (e, stackTrace) {
    _logger.e(
      'Failed to update suggestion $suggestionId status',
      error: e,
      stackTrace: stackTrace,
      tag: 'SUGGESTIONS',
    );
    rethrow;
  }
}
  // Clean up old accepted suggestions (should be called periodically)
  Future<void> cleanupOldAcceptedSuggestions() async {
    try {
      _logger.i('Cleaning up old accepted suggestions', tag: 'MAINTENANCE');
      
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final oldSuggestions = await _firestore
          .collection('suggestions')
          .where('status', isEqualTo: 'accepted')
          .where('acceptedAt', isLessThan: Timestamp.fromDate(weekAgo))
          .get();

      final batch = _firestore.batch();
      int deletedCount = 0;

      for (final doc in oldSuggestions.docs) {
        batch.delete(doc.reference);
        deletedCount++;
      }

      if (deletedCount > 0) {
        await batch.commit();
        _logger.i('Deleted $deletedCount old accepted suggestions', tag: 'MAINTENANCE');
      } else {
        _logger.i('No old accepted suggestions to delete', tag: 'MAINTENANCE');
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to cleanup old accepted suggestions',
        error: e,
        stackTrace: stackTrace,
        tag: 'MAINTENANCE',
      );
    }
  }

  // Getters
  FirebaseAuth get auth => FirebaseAuth.instance;
}