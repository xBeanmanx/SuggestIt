import 'package:suggest_it/services/firebase_service.dart';
import 'package:flutter/material.dart';

/// Input widget for creating private suggestions
///
/// [userId] - Required parameter identifying the submitting user
/// [groupId] - Required parameter specifying target group
class PrivateSuggestionInput extends StatefulWidget {
  final String userId;
  final String groupId;
  
  const PrivateSuggestionInput({
    super.key,
    required this.userId,
    required this.groupId,
  });

  @override
  _PrivateSuggestionInputState createState() => _PrivateSuggestionInputState();
}

class _PrivateSuggestionInputState extends State<PrivateSuggestionInput> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();

  Future<void> _submitSuggestion() async {
    if (_controller.text.isEmpty) return;

    try {
      await _firebaseService.addSuggestion(
        widget.groupId,
        _controller.text,
        widget.userId,
      );
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Add a private suggestion...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _submitSuggestion,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
