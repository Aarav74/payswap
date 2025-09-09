// screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(user, theme),
            SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildProfileCard(user, theme),
                  SizedBox(height: 16),
                  _buildActionsCard(context, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User? user, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 2),
          ),
          child: Icon(
            Icons.person,
            size: 30,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.userMetadata?['name'] ?? 'Guest User',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 4),
              Text(
                user?.email ?? 'No email provided',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(User? user, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            SizedBox(height: 20),
            _buildInfoTile(
              icon: Icons.person,
              title: 'Full Name',
              value: user?.userMetadata?['name'] ?? 'Not provided',
            ),
            Divider(height: 20),
            _buildInfoTile(
              icon: Icons.email,
              title: 'Email Address',
              value: user?.email ?? 'No email',
            ),
            Divider(height: 20),
            _buildInfoTile(
              icon: Icons.phone,
              title: 'Phone Number',
              value: user?.phone ?? 'Not provided',
            ),
            Divider(height: 20),
            _buildInfoTile(
              icon: Icons.calendar_today,
              title: 'Member Since',
              value: user?.createdAt != null 
                  ? '${DateTime.parse(user!.createdAt!).year}'
                  : 'Unknown',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String title, required String value}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: Colors.blue),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey[900],
        ),
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            SizedBox(height: 20),
            _buildActionTile(
              context: context,
              icon: Icons.edit,
              title: 'Update Profile',
              color: Colors.blue,
              onTap: () {
                // Navigate to update profile screen
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Update profile feature coming soon!')),
                );
              },
            ),
            _buildActionTile(
              context: context,
              icon: Icons.payment,
              title: 'Payment Methods',
              color: Colors.green,
              onTap: () {
                // Navigate to payment methods
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payment methods feature coming soon!')),
                );
              },
            ),
            _buildActionTile(
              context: context,
              icon: Icons.history,
              title: 'Transaction History',
              color: Colors.purple,
              onTap: () {
                // Navigate to transaction history
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Transaction history feature coming soon!')),
                );
              },
            ),
            _buildActionTile(
              context: context,
              icon: Icons.settings,
              title: 'App Settings',
              color: Colors.orange,
              onTap: () {
                // Navigate to settings
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Settings feature coming soon!')),
                );
              },
            ),
            SizedBox(height: 10),
            Divider(height: 20),
            _buildActionTile(
              context: context,
              icon: Icons.logout,
              title: 'Logout',
              color: Colors.red,
              onTap: () {
                _showLogoutDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.grey[800],
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to logout from your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final authService = Provider.of<AuthService>(context, listen: false);
              authService.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }
}