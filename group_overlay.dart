import 'package:flutter/material.dart';
import 'package:suggest_it/widgets/suggestion_card.dart';
import 'package:suggest_it/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Dialog showing detailed group information and suggestions
//
/// [groupId] - Required parameter specifying which group to display
class GroupOverlayDialog extends StatefulWidget {
  final String groupId;

  const GroupOverlayDialog({super.key, required this.groupId});

  @override
  State<GroupOverlayDialog> createState() => _GroupOverlayDialogState();
}

class _GroupOverlayDialogState extends State<GroupOverlayDialog> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(128.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firebaseService.getGroupStream(widget.groupId),
          builder: (context, groupSnapshot) {
            if (groupSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (groupSnapshot.hasError) {
              return Center(
                child: Text('Error loading group: ${groupSnapshot.error}'),
              );
            }

            if (!groupSnapshot.hasData || !groupSnapshot.data!.exists) {
              return const Center(child: Text('Group not found'));
            }

            final groupData = groupSnapshot.data!.data() as Map<String, dynamic>;
            final members = List<String>.from(groupData['members'] ?? []);
            final totalMembers = members.length;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupData['name'] ?? 'Unnamed Group',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Members: $totalMembers',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),

                const Divider(),
                
                // Accepted Suggestions Section
                const Padding(
                  padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Text(
                    'Accepted Suggestions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                _buildSuggestionsList('accepted', totalMembers, groupData['name'] ?? 'Group'),
                
                const SizedBox(height: 16),
                const Divider(),
                
                // Pending Suggestions Section
                const Padding(
                  padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Text(
                    'Pending Suggestions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
                _buildSuggestionsList('pending', totalMembers, groupData['name'] ?? 'Group'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(String status, int totalMembers, String groupName) {
    // Use the appropriate stream based on status
    final stream = status == 'accepted'
        ? _firebaseService.getAcceptedSuggestionsStream([widget.groupId])
        : _firebaseService.getPendingSuggestionsStream([widget.groupId]);

    return Expanded(
      child: StreamBuilder<List<DocumentSnapshot>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading $status suggestions: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  status == 'accepted' 
                      ? 'No accepted suggestions yet' 
                      : 'No pending suggestions yet',
                  style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            );
          }

          final suggestions = snapshot.data!;

          return ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              final data = suggestion.data() as Map<String, dynamic>;
              final votes = data['votes'] as Map<String, dynamic>? ?? {};
              final agreedCount = votes.values.where((v) => v == true).length;
              final declinedCount = votes.values.where((v) => v == false).length;
              
              final currentUser = _auth.currentUser;
              final userVote = currentUser != null && status == 'pending'
                  ? votes[currentUser.uid] as bool?
                  : null;

              final acceptedAt = data['acceptedAt'] as Timestamp?;
              int? daysRemaining;
              if (acceptedAt != null && status == 'accepted') {
                final acceptedDate = acceptedAt.toDate();
                final now = DateTime.now();
                final difference = now.difference(acceptedDate);
                daysRemaining = 7 - difference.inDays;
                if (daysRemaining < 0) daysRemaining = 0;
              }

              return SuggestionCard(
                suggestionText: data['text'] ?? '',
                agreedCount: agreedCount,
                declinedCount: declinedCount,
                totalMembers: totalMembers,
                suggestionId: suggestion.id,
                groupId: widget.groupId,
                userVote: userVote,
                status: status,
                groupName: groupName,
                acceptedAt: acceptedAt,
                daysRemaining: daysRemaining,
              );
            },
          );
        },
      ),
    );
  }
}