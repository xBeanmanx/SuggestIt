import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfilePopup extends StatelessWidget {
  final User? currentUser;
  final VoidCallback onSignOut;

  const ProfilePopup({
    super.key,
    required this.currentUser,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          const SizedBox(height: 20),
          if (currentUser != null) _buildUserInfo(context),
          _buildSignOutButton(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: currentUser!.photoURL != null
                ? NetworkImage(currentUser!.photoURL!)
                : null,
            backgroundColor: currentUser!.photoURL == null
                ? Colors.blue
                : Colors.transparent,
            child: currentUser!.photoURL == null
                ? const Icon(Icons.person, size: 40, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            currentUser!.displayName ?? 'User',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentUser!.email ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildUserIdSection(context),
          const SizedBox(height: 8),
          Text(
            'Share this ID with friends to add you',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildUserIdSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              'ID: ${currentUser!.uid}',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              _copyUserIdToClipboard(context);
            },
          ),
        ],
      ),
    );
  }

  void _copyUserIdToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: currentUser!.uid));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User ID copied to clipboard'),
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.logout, color: Colors.red),
      title: const Text(
        'Sign Out',
        style: TextStyle(color: Colors.red),
      ),
      onTap: () {
        Navigator.pop(context);
        onSignOut();
      },
    );
  }
}