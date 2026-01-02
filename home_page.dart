import 'package:suggest_it/services/firebase_service.dart';
import 'package:suggest_it/widgets/group_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:suggest_it/services/logging_service.dart';
import 'package:suggest_it/widgets/suggestion_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> _userGroupIds = [];
  Map<String, String> _groupNames = {};

  @override
  void initState() {
    super.initState();
    _loadUserGroups();
  }

  Future<void> _loadUserGroups() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final groupIds = List<String>.from(userData['groups'] ?? []);

          // Load group names
          final groupNames = <String, String>{};
          for (final groupId in groupIds) {
            final groupDoc = await FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .get();
            if (groupDoc.exists) {
              groupNames[groupId] = groupDoc.data()?['name'] ?? 'Unknown Group';
            }
          }

          setState(() {
            _userGroupIds = groupIds;
            _groupNames = groupNames;
          });
        }
      } catch (e) {
        final logger = AppLogger();
        logger.d("Error loading user groups", error: e);
        logger.firebase(
          'document_created',
          collection: 'users',
          error: e,
          documentId: user.uid,
        );
      }
    }
  }

  void _openGroupOverlay(String groupId, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => GroupOverlayDialog(groupId: groupId),
    );
  }

  void _showAddSuggestionDialog(BuildContext context) {
    // If user is not in any groups, show a message
    if (_userGroupIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to join a group first to add suggestions'),
        ),
      );
      return;
    }

    // If user has only one group, add suggestion directly to that group
    if (_userGroupIds.length == 1) {
      _addSuggestionToGroup(_userGroupIds.first, context);
    } else {
      // If user has multiple groups, show a dialog to select a group
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select a Group'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _userGroupIds.length,
              itemBuilder: (context, index) {
                final groupId = _userGroupIds[index];
                final groupName = _groupNames[groupId] ?? 'Unknown Group';

                return ListTile(
                  leading: const Icon(Icons.group),
                  title: Text(groupName),
                  onTap: () {
                    Navigator.pop(context); // Close group selection dialog
                    _addSuggestionToGroup(groupId, context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
  }

  void _addSuggestionToGroup(String groupId, BuildContext context) {
    final TextEditingController textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Suggestion'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: 'Enter your suggestion',
            hintText: 'Type your suggestion here...',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a suggestion')),
                );
                return;
              }

              try {
                final user = _auth.currentUser;
                if (user != null) {
                  // Add suggestion to Firestore using FirebaseService
                  await _firebaseService.addSuggestion(groupId, text, user.uid);
                  // Log the action
                  final logger = AppLogger();
                  logger.d("Suggestion added to group $groupId");
                  logger.firebase(
                    'document_created',
                    collection: 'suggestions',
                    documentId: groupId,
                    data: {'groupId': groupId},
                  );

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Suggestion added successfully!'),
                    ),
                  );

                  Navigator.pop(context); // Close dialog
                }
              } catch (e) {
                final logger = AppLogger();
                logger.d("Error adding suggestion", error: e);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error adding suggestion: ${e.toString()}'),
                  ),
                );
              }
            },
            child: const Text('Add Suggestion'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suggestions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSuggestionDialog(context),
        child: const Icon(Icons.add),
      ),
      body: _userGroupIds.isEmpty
          ? _buildNoGroupsView()
          : _buildSuggestionsView(),
    );
  }

  Widget _buildNoGroupsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_objects, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No groups yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join or create a group to see suggestions',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // TODO:  Navigate to friends page to create group
              // This would require passing a callback from main_navigation
            },
            child: const Text('Create a Group'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsView() {
    return CustomScrollView(
      slivers: [
        // Accepted Suggestions Section (Top)
        SliverToBoxAdapter(child: _buildAcceptedSuggestionsHeader()),
        _buildAcceptedSuggestionsList(),

        // Pending Suggestions Section
        SliverToBoxAdapter(child: _buildPendingSuggestionsHeader()),
        _buildPendingSuggestionsList(),
      ],
    );
  }

  Widget _buildAcceptedSuggestionsHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(Icons.verified, color: Colors.green, size: 24),
          SizedBox(width: 8),
          Text(
            'Accepted Suggestions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSuggestionsHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(Icons.pending, color: Colors.orange, size: 24),
          SizedBox(width: 8),
          Text(
            'Pending Suggestions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedSuggestionsList() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _firebaseService.getAcceptedSuggestionsStream(_userGroupIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Container(
              height: 100,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading accepted suggestions: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No accepted suggestions yet',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          );
        }

        final suggestions = snapshot.data!;

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final suggestion = suggestions[index];
            final data = suggestion.data() as Map<String, dynamic>;
            final votes = data['votes'] as Map<String, dynamic>? ?? {};
            final agreedCount = votes.values.where((v) => v == true).length;
            final declinedCount = votes.values.where((v) => v == false).length;
            final groupId = data['groupId'] ?? '';
            final groupName = _groupNames[groupId] ?? 'Group';
            final acceptedAt = data['acceptedAt'] as Timestamp?;

            // Calculate days remaining until deletion
            int daysRemaining = 7;
            if (acceptedAt != null) {
              final acceptedDate = acceptedAt.toDate();
              final now = DateTime.now();
              final difference = now.difference(acceptedDate);
              daysRemaining = 7 - difference.inDays;
              if (daysRemaining < 0) daysRemaining = 0;
            }

            return SuggestionCard(
              suggestionText: data['text'] ?? 'No text',
              agreedCount: agreedCount,
              declinedCount: declinedCount,
              totalMembers: _userGroupIds.length,
              suggestionId: suggestion.id,
              groupId: groupId,
              userVote: null, // No voting on accepted suggestions
              status: 'accepted',
              groupName: groupName,
              acceptedAt: acceptedAt,
              daysRemaining: daysRemaining,
              onTap: () {
                if (groupId.isNotEmpty) {
                  _openGroupOverlay(groupId, context);
                }
              },
            );
          }, childCount: suggestions.length),
        );
      },
    );
  }

  Widget _buildPendingSuggestionsList() {
    // Use the new method that returns Stream<List<DocumentSnapshot>>
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _firebaseService.getPendingSuggestionsStream(_userGroupIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Container(
              height: 100,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading pending suggestions: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No pending suggestions',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          );
        }

        final suggestions = snapshot.data!;

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final suggestion = suggestions[index];
            final data = suggestion.data() as Map<String, dynamic>;
            final votes = data['votes'] as Map<String, dynamic>? ?? {};
            final agreedCount = votes.values.where((v) => v == true).length;
            final declinedCount = votes.values.where((v) => v == false).length;
            final groupId = data['groupId'] ?? '';
            final groupName = _groupNames[groupId] ?? 'Group';

            // Get current user's vote if any
            final currentUser = _auth.currentUser;
            final userVote = currentUser != null
                ? votes[currentUser.uid] as bool?
                : null;

            return SuggestionCard(
              suggestionText: data['text'] ?? 'No text',
              agreedCount: agreedCount,
              declinedCount: declinedCount,
              totalMembers: _userGroupIds.length,
              suggestionId: suggestion.id,
              groupId: groupId,
              userVote: userVote,
              status: 'pending',
              groupName: groupName,
              onTap: () {
                if (groupId.isNotEmpty) {
                  _openGroupOverlay(groupId, context);
                }
              },
            );
          }, childCount: suggestions.length),
        );
      },
    );
  }
}