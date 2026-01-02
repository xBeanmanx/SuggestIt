import 'package:suggest_it/widgets/group_overlay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GroupsPage extends StatefulWidget {
  final Function()? onNavigateToFriends;

  const GroupsPage({super.key, this.onNavigateToFriends});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  String? _error;
  final Map<String, String> _userNames = {}; // Cache for user display names

  @override
  void initState() {
    super.initState();
    _loadUserGroups();
  }

  Future<void> _loadUserGroups() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _error = 'Not logged in';
        });
        return;
      }

      // Get user document to get group IDs
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _isLoading = false;
          _error = 'User profile not found. Please sign in again.';
        });
        return;
      }

      final userData = userDoc.data();
      final groupIds = List<String>.from(userData?['groups'] ?? []);

      if (groupIds.isEmpty) {
        setState(() {
          _isLoading = false;
          _groups = [];
        });
        return;
      }

      // Load all group documents
      final List<Map<String, dynamic>> loadedGroups = [];
      final Set<String> userIds = {}; // Collect user IDs to fetch names

      for (final groupId in groupIds) {
        final groupDoc = await _firestore
            .collection('groups')
            .doc(groupId)
            .get();

        if (groupDoc.exists) {
          final groupData = groupDoc.data()!;
          final members = List<String>.from(groupData['members'] ?? []);
          final createdBy = groupData['createdBy'] as String?;
          
          // Add creator to user IDs to fetch
          if (createdBy != null) userIds.add(createdBy);
          
          loadedGroups.add({
            'id': groupId,
            'name': groupData['name'] ?? 'Unnamed Group',
            'members': members,
            'createdBy': createdBy,
            'createdAt': groupData['createdAt'],
          });
        }
      }

      // Fetch user display names for creators
      if (userIds.isNotEmpty) {
        final usersSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: userIds.toList())
            .get();
        
        for (final userDoc in usersSnapshot.docs) {
          final userData = userDoc.data();
          _userNames[userDoc.id] = userData['displayName'] ?? userData['email'] ?? 'Unknown';
        }
      }

      setState(() {
        _groups = loadedGroups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load groups: $e';
      });
    }
  }

  Future<void> _refreshGroups() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _loadUserGroups();
  }

  String _getCreatorName(String? creatorId) {
    if (creatorId == null) return 'Unknown';
    return _userNames[creatorId] ?? 'User $creatorId';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Groups',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _refreshGroups,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshGroups,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_add, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No groups yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a group from the Friends page',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshGroups,
      child: ListView.builder(
        itemCount: _groups.length,
        itemBuilder: (context, index) {
          final group = _groups[index];
          final members = List<String>.from(group['members'] ?? []);
          final memberCount = members.length;
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Text(
                  group['name'].substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              title: Text(
                group['name'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('$memberCount member${memberCount == 1 ? '' : 's'}'),
                  Text(
                    'Created by: ${_getCreatorName(group['createdBy'])}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (group['createdAt'] != null)
                    Text(
                      'Created ${_formatDate(group['createdAt'])}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => GroupOverlayDialog(
                    groupId: group['id'],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'recently';
    
    try {
      final date = timestamp is Timestamp 
          ? timestamp.toDate()
          : timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        return 'just now';
      }
    } catch (e) {
      return 'recently';
    }
  }
}