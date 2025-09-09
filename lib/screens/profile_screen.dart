import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  if (user != null) ...[
                    ListTile(
                      leading: Icon(Icons.person),
                      title: Text('Name'),
                      subtitle: Text(
                        user.userMetadata?['name'] ?? 'Not provided',
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.email),
                      title: Text('Email'),
                      subtitle: Text(user.email ?? 'No email'),
                    ),
                    ListTile(
                      leading: Icon(Icons.phone),
                      title: Text('Phone'),
                      subtitle: Text(user.phone ?? 'Not provided'),
                    ),
                  ] else
                    Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Update Profile'),
                    onTap: () {
                      // Navigate to update profile screen
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.payment),
                    title: Text('Payment Methods'),
                    onTap: () {
                      // Navigate to payment methods screen
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.history),
                    title: Text('Transaction History'),
                    onTap: () {
                      // Navigate to transaction history
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.red),
                    title: Text('Logout', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      authService.logout();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
