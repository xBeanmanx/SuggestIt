import 'package:suggest_it/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _friendIdController = TextEditingController();
  bool _isLoading = false;
  bool _isCreating = false;
  bool _isSearching = false;
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Store search results and selected friends
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _currentFriends = [];
  final List<Map<String, dynamic>> _selectedFriends = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentFriends();
  }

  void _loadCurrentFriends() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    _firebaseService
        .getUserFriends(currentUserId)
        .then((friendsDocs) {
          if (mounted) {
            setState(() {
            _currentFriends = friendsDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'id': doc.id,
                'email': data['email'],
                'displayName': data['displayName'],
                'photoURL': data['photoURL'],
              };
            }).toList();
          });
          }
        })
        .catchError((error) {
          SnackBar(content: Text('Error loading friends: $error'));
        });
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    if (mounted) {
      setState(() {
      _isSearching = true;
      _searchResults.clear();
    });
    }

    try {
      final results = await _firebaseService.searchUsersByEmail(query);
      final currentUserId = _auth.currentUser?.uid;

      final List<Map<String, dynamic>> users = [];
      for (final doc in results) {
        final data = doc.data() as Map<String, dynamic>;
        // Don't show current user or already added friends
        if (doc.id != currentUserId &&
            !_currentFriends.any((friend) => friend['id'] == doc.id)) {
          users.add({
            'id': doc.id,
            'email': data['email'],
            'displayName': data['displayName'],
            'photoURL': data['photoURL'],
          });
        }
      }
      if (mounted) {
        setState(() {
          _searchResults = users;
        });
      }
    } catch (e) {
      _showErrorDialog('Search failed: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _addFriendById() async {
    final friendId = _friendIdController.text.trim();
    if (friendId.isEmpty) {
      _showErrorDialog('Please enter a friend ID');
      return;
    }
    if (mounted) {
      setState(() {
      _isLoading = true;
    });
    }

    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        _showErrorDialog('You must be logged in');
        return;
      }

      if (friendId == currentUserId) {
        _showErrorDialog('You cannot add yourself as a friend');
        return;
      }

      // Check if friend exists
      final friendDoc = await _firebaseService.getUserDocument(friendId);
      if (!friendDoc.exists) {
        _showErrorDialog('User not found with this ID');
        return;
      }

      // Check if already friends
      final friendData = friendDoc.data() as Map<String, dynamic>;
      final friendFriends = List<String>.from(friendData['friends'] ?? []);
      if (friendFriends.contains(currentUserId)) {
        _showErrorDialog('You are already friends with this user');
        return;
      }

      await _firebaseService.addFriend(currentUserId, friendId);

      // Reload friends list
      _loadCurrentFriends();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend added successfully')),
      );
      }

      _friendIdController.clear();
    } catch (e) {
      _showErrorDialog('Failed to add friend: $e');
    } finally {
      if (mounted) {
        setState(() {
        _isLoading = false;
      });
      }
    }
  }

  Future<void> _addFriendBySearch(Map<String, dynamic> user) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      await _firebaseService.addFriend(currentUserId, user['id']);

      // Add to current friends list
      if (mounted) {
        setState(() {
        _currentFriends.add(user);
        _searchResults.removeWhere((u) => u['id'] == user['id']);
      });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${user['displayName'] ?? user['email']} as friend',
          ),
        ),
      );
      }
    } catch (e) {
      _showErrorDialog('Failed to add friend: $e');
    }
  }

  void _toggleFriendSelection(Map<String, dynamic> friend) {
    if (mounted) {
      setState(() {
      if (_selectedFriends.contains(friend)) {
        _selectedFriends.remove(friend);
      } else {
        _selectedFriends.add(friend);
      }
    });
    }
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      _showErrorDialog('Please enter a group name');
      return;
    }

    if (_selectedFriends.isEmpty) {
      _showErrorDialog('Please select at least one friend');
      return;
    }

    if (mounted) {
      setState(() => _isCreating = true);
    }

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _showErrorDialog('You must be logged in to create a group');
        return;
      }

      final allMembers = _selectedFriends.map((f) => f['id']).toList();
      allMembers.add(currentUser.uid);

      if (allMembers.length < 2) {
        _showErrorDialog('A group must have at least 2 members');
        return;
      }

      await _firebaseService.createGroup(
        groupName,
        allMembers,
        currentUser.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "$groupName" created successfully')),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Group creation failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _resetForm() {
    if (mounted) {
      setState(() {
      _groupNameController.clear();
      _selectedFriends.clear();
    });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'My Friends'),
              Tab(icon: Icon(Icons.person_add), text: 'Add Friends'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: My Friends
            _buildMyFriendsTab(),

            // Tab 2: Add Friends
            _buildAddFriendsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyFriendsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group creation section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create New Group',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _groupNameController,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_currentFriends.isNotEmpty)
                    const Text(
                      'Select Friends for Group:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Friends list
          Expanded(
            child: _currentFriends.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No friends yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add friends using the "Add Friends" tab',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _currentFriends.length,
                    itemBuilder: (context, index) {
                      final friend = _currentFriends[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(
                            left: 16,
                            right: 8,
                            top: 4,
                            bottom: 4,
                          ),
                          leading: Checkbox(
                            value: _selectedFriends.contains(friend),
                            onChanged: (_) => _toggleFriendSelection(friend),
                          ),
                          title: Row(
                            children: [
                              CircleAvatar(
                                backgroundImage: friend['photoURL'] != null
                                    ? NetworkImage(friend['photoURL'])
                                    : null,
                                radius: 20,
                                child: friend['photoURL'] == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friend['displayName'] ?? friend['email'],
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    if (friend['displayName'] != null)
                                      Text(
                                        friend['email'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              _showRemoveFriendDialog(friend);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Create group button
          if (_currentFriends.isNotEmpty && _selectedFriends.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isCreating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Create Group with ${_selectedFriends.length} friend(s)',
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddFriendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add friend by ID section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Friend by ID',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask your friend to share their User ID from their profile',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _friendIdController,
                          decoration: const InputDecoration(
                            hintText: 'Enter friend\'s User ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _addFriendById,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(),
                              )
                            : const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Search friends by email
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Users by Email',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Enter email address...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSearching ? null : _searchUsers,
                        child: _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(),
                              )
                            : const Text('Search'),
                      ),
                    ],
                  ),

                  if (_searchResults.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Search Results:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ..._searchResults.map((user) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundImage: user['photoURL'] != null
                                    ? NetworkImage(user['photoURL'])
                                    : null,
                                child: user['photoURL'] == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(user['displayName'] ?? user['email']),
                              subtitle: user['displayName'] != null
                                  ? Text(user['email'])
                                  : null,
                              trailing: ElevatedButton(
                                onPressed: () => _addFriendBySearch(user),
                                child: const Text('Add Friend'),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveFriendDialog(Map<String, dynamic> friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
          'Are you sure you want to remove ${friend['displayName'] ?? friend['email']} from your friends?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFriend(friend['id']);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFriend(String friendId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      await _firebaseService.removeFriend(currentUserId, friendId);

      // Update the friends list
      if (mounted) {
        setState(() {
        _currentFriends.removeWhere((friend) => friend['id'] == friendId);
        // Also remove from selected friends if present
        _selectedFriends.removeWhere((friend) => friend['id'] == friendId);
      });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend removed successfully')),
      );
      }
    } catch (e) {
      _showErrorDialog('Failed to remove friend: $e');
    }
  }
}
