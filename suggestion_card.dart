import 'package:flutter/material.dart';
import 'package:suggest_it/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SuggestionCard extends StatelessWidget {
  final String suggestionText;
  final int agreedCount;
  final int declinedCount;
  final int totalMembers;
  final String suggestionId;
  final String groupId;
  final bool? userVote;
  final String status;
  final String? groupName;
  final Timestamp? acceptedAt;
  final int? daysRemaining;
  final VoidCallback? onTap;

  const SuggestionCard({
    super.key,
    required this.suggestionText,
    required this.agreedCount,
    required this.declinedCount,
    required this.totalMembers,
    required this.suggestionId,
    required this.groupId,
    this.userVote,
    required this.status,
    this.groupName,
    this.acceptedAt,
    this.daysRemaining,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final agreedPercentage = totalMembers > 0 
        ? (agreedCount / totalMembers * 100).round() 
        : 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: status == 'accepted' ? 4 : 2,
      color: status == 'accepted' ? Colors.green[50] : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group name badge
              if (groupName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.group, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          groupName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Suggestion text
              Text(
                suggestionText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: status == 'accepted' ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 12),
              
              // Voting section or acceptance info
              if (status == 'accepted') 
                _buildAcceptedSection(context)
              else 
                _buildVotingSection(context),
              
              // Progress bar
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: totalMembers > 0 ? agreedCount / totalMembers : 0,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  status == 'accepted' ? Colors.green : 
                  agreedPercentage >= 50 ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              
              // Status and stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          status == 'accepted' ? Icons.verified : Icons.pending,
                          size: 14,
                          color: _getStatusColor(status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Stats
                  Row(
                    children: [
                      _buildStatIcon(Icons.favorite, Colors.red, agreedCount),
                      const SizedBox(width: 8),
                      _buildStatIcon(Icons.close, Colors.grey, declinedCount),
                    ],
                  ),
                ],
              ),
              
              // Days remaining for accepted suggestions
              if (status == 'accepted' && daysRemaining != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 14,
                        color: daysRemaining! <= 2 ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        daysRemaining! > 0 
                            ? 'Will be deleted in $daysRemaining ${daysRemaining == 1 ? 'day' : 'days'}'
                            : 'Will be deleted soon',
                        style: TextStyle(
                          fontSize: 12,
                          color: daysRemaining! <= 2 ? Colors.red : Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVotingSection(BuildContext context) {
    return Row(
      children: [
        // Agree button
        IconButton(
          icon: Icon(
            Icons.favorite,
            color: userVote == true ? Colors.red : Colors.grey,
            size: 28,
          ),
          onPressed: () => _handleVote(context, true),
          tooltip: 'Agree with this suggestion',
        ),
        
        // Decline button
        IconButton(
          icon: Icon(
            Icons.close,
            color: userVote == false ? Colors.black : Colors.grey,
            size: 28,
          ),
          onPressed: () => _handleVote(context, false),
          tooltip: 'Decline this suggestion',
        ),
        
        const Spacer(),
        
        // Stats
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$agreedCount/$totalMembers agreed',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '${((agreedCount / totalMembers) * 100).round()}%',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAcceptedSection(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[100],
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified,
            color: Colors.green,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Accepted by majority',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              if (acceptedAt != null)
                Text(
                  'Accepted ${_formatDate(acceptedAt!.toDate())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$agreedCount/$totalMembers agreed',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Text(
              'MAJORITY',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatIcon(IconData icon, Color color, int count) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 2),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _handleVote(BuildContext context, bool vote) async {
    try {
      final firebaseService = FirebaseService();
      final currentUser = firebaseService.auth.currentUser;
      
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to vote')),
        );
        return;
      }

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(width: 12),
              Text('Submitting ${vote ? 'agree' : 'decline'} vote...'),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      await firebaseService.voteOnSuggestion(
        suggestionId,
        currentUser.uid,
        vote,
      );

      // Success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vote ? 'You agreed with this suggestion' : 'You declined this suggestion',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to vote: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 30) return '${difference.inDays}d ago';
    
    final months = (difference.inDays / 30).floor();
    return '$months ${months == 1 ? 'month' : 'months'} ago';
  }
}