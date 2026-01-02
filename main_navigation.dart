import 'package:suggest_it/navigation/page_controller.dart';
import 'package:suggest_it/services/auth_service.dart';
import 'package:suggest_it/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:suggest_it/main_pages/home_page.dart';
import 'package:suggest_it/main_pages/groups_page.dart';
import 'package:suggest_it/main_pages/friends_page.dart';
import 'package:suggest_it/widgets/profile_popup.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  User? _currentUser;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
    
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _firebaseService.createUserDocument(user);
      }
      setState(() {
        _currentUser = user;
      });
    });
  }

  void _checkCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _currentUser = user;
    });
  }

  Future<void> _handleSignIn() async {
    final user = await AuthService().signInWithGoogle();
    if (user != null) {
      await _firebaseService.createUserDocument(user);
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _handleSignOut() async {
    await AuthService().signOut();
    setState(() {
      _currentUser = null;
    });
  }

  void _navigateToFriendsPage() {
    _pageController.jumpToPage(2);
    setState(() {
      _currentIndex = 2;
    });
  }

  void _showProfilePopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfilePopup(
        currentUser: _currentUser,
        onSignOut: _handleSignOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SuggestIt',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_currentUser == null)
            _buildSignInButton()
          else
            _buildProfileAvatar(),
        ],
      ),
      body: MouseWheelPageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          const HomePage(),
          GroupsPage(onNavigateToFriends: _navigateToFriendsPage),
          const FriendsPage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildSignInButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ElevatedButton.icon(
        onPressed: _handleSignIn,
        icon: const Icon(Icons.login),
        label: const Text('Sign In'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue,
          elevation: 1,
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () => _showProfilePopup(context),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 20,
            backgroundImage: _currentUser!.photoURL != null
                ? NetworkImage(_currentUser!.photoURL!)
                : null,
            backgroundColor: _currentUser!.photoURL == null
                ? Colors.blue
                : Colors.transparent,
            child: _currentUser!.photoURL == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }

  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        _pageController.jumpToPage(index);
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.group),
          label: 'Groups',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Friends',
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}