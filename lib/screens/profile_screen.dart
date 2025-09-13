import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isEditing = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  List<PaymentMethod> _paymentMethods = [];
  

  List<Transaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    
    _fadeController.forward();
    _slideController.forward();
    
    _loadUserData();
    _loadPaymentMethods();
    _loadTransactionHistory();
  }

  void _loadUserData() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    _nameController.text = user?.userMetadata?['name'] ?? '';
    _phoneController.text = user?.phone ?? '';
  }

  void _loadPaymentMethods() {
    // Simulated payment methods - replace with actual API call
    setState(() {
      _paymentMethods = [
        PaymentMethod(
          id: '1',
          type: 'visa',
          lastFour: '4242',
          isDefault: true,
        ),
        PaymentMethod(
          id: '2',
          type: 'paypal',
          email: 'user@example.com',
          isDefault: false,
        ),
      ];
    });
  }

  void _loadTransactionHistory() {
    // Simulated transaction history - replace with actual API call
    setState(() {
      _transactions = [
        Transaction(
          id: '1',
          amount: 50.0,
          type: 'received',
          description: 'Cash exchange with John',
          date: DateTime.now().subtract(Duration(hours: 2)),
          status: 'completed',
        ),
        Transaction(
          id: '2',
          amount: 25.0,
          type: 'sent',
          description: 'Online payment to Sarah',
          date: DateTime.now().subtract(Duration(days: 1)),
          status: 'completed',
        ),
        Transaction(
          id: '3',
          amount: 100.0,
          type: 'received',
          description: 'Cash exchange with Mike',
          date: DateTime.now().subtract(Duration(days: 3)),
          status: 'pending',
        ),
      ];
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(user, theme),
              SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildProfileCard(user, theme),
                    SizedBox(height: 16),
                    _buildStatsCard(theme),
                    SizedBox(height: 16),
                    _buildQuickActionsCard(theme),
                    SizedBox(height: 16),
                    _buildPaymentMethodsCard(theme),
                    SizedBox(height: 16),
                    _buildTransactionHistoryCard(theme),
                    SizedBox(height: 16),
                    _buildSettingsCard(theme),
                    SizedBox(height: 100), // Bottom padding
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(User? user, ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: theme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.primaryColor,
                theme.primaryColor.withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 40),
                Hero(
                  tag: 'profile-avatar',
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.white.withOpacity(0.9)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  user?.userMetadata?['name'] ?? 'Guest User',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  user?.email ?? 'No email provided',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(User? user, ThemeData theme) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      child: Card(
        elevation: 8,
        shadowColor: theme.primaryColor.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey[50]!,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, color: theme.primaryColor, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Profile Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () => _toggleEditMode(),
                      icon: Icon(
                        _isEditing ? Icons.check : Icons.edit,
                        color: theme.primaryColor,
                      ),
                      tooltip: _isEditing ? 'Save' : 'Edit',
                    ),
                  ],
                ),
                SizedBox(height: 24),
                _buildAnimatedInfoTile(
                  icon: Icons.person,
                  title: 'Full Name',
                  value: user?.userMetadata?['name'] ?? 'Not provided',
                  controller: _nameController,
                  isEditable: true,
                ),
                _buildDivider(),
                _buildAnimatedInfoTile(
                  icon: Icons.email,
                  title: 'Email Address',
                  value: user?.email ?? 'No email',
                  isEditable: false,
                ),
                _buildDivider(),
                _buildAnimatedInfoTile(
                  icon: Icons.phone,
                  title: 'Phone Number',
                  value: user?.phone ?? 'Not provided',
                  controller: _phoneController,
                  isEditable: true,
                ),
                _buildDivider(),
                _buildAnimatedInfoTile(
                  icon: Icons.calendar_today,
                  title: 'Member Since',
                  value: user?.createdAt != null 
                      ? '${DateTime.parse(user!.createdAt!).year}'
                      : 'Unknown',
                  isEditable: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text(
                'Your PaySwap Stats',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Total Exchanges', '12', Icons.swap_horiz),
                  _buildStatItem('Amount Traded', '\$1,250', Icons.attach_money),
                  _buildStatItem('Rating', '4.8', Icons.star),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard(ThemeData theme) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: theme.primaryColor, size: 28),
                SizedBox(width: 12),
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3,
              children: [
                _buildQuickActionButton(
                  'Update Profile',
                  Icons.edit,
                  Colors.blue,
                  () => _toggleEditMode(),
                ),
                _buildQuickActionButton(
                  'Add Payment',
                  Icons.add_card,
                  Colors.green,
                  () => _showAddPaymentMethod(),
                ),
                _buildQuickActionButton(
                  'View History',
                  Icons.history,
                  Colors.purple,
                  () => _showTransactionHistory(),
                ),
                _buildQuickActionButton(
                  'Settings',
                  Icons.settings,
                  Colors.orange,
                  () => _showAppSettings(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsCard(ThemeData theme) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: theme.primaryColor, size: 28),
                SizedBox(width: 12),
                Text(
                  'Payment Methods',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => _showAddPaymentMethod(),
                  icon: Icon(Icons.add, color: theme.primaryColor),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_paymentMethods.isEmpty)
              _buildEmptyState('No payment methods added', Icons.payment)
            else
              ...(_paymentMethods.map((method) => _buildPaymentMethodTile(method, theme))),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(PaymentMethod method, ThemeData theme) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: method.isDefault ? Border.all(color: theme.primaryColor, width: 2) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getPaymentMethodColor(method.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getPaymentMethodIcon(method.type),
              color: _getPaymentMethodColor(method.type),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getPaymentMethodName(method.type),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  method.lastFour != null ? '**** ${method.lastFour}' : method.email ?? '',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          if (method.isDefault)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Default',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistoryCard(ThemeData theme) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: theme.primaryColor, size: 28),
                SizedBox(width: 12),
                Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                Spacer(),
                TextButton(
                  onPressed: () => _showTransactionHistory(),
                  child: Text('View All'),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_transactions.isEmpty)
              _buildEmptyState('No transactions yet', Icons.receipt_long)
            else
              ...(_transactions.take(3).map((transaction) => _buildTransactionTile(transaction))),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(Transaction transaction) {
    final isReceived = transaction.type == 'received';
    final color = isReceived ? Colors.green : Colors.red;
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isReceived ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatDate(transaction.date),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isReceived ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: transaction.status == 'completed' ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  transaction.status.toUpperCase(),
                  style: TextStyle(color: Colors.white, fontSize: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(ThemeData theme) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: theme.primaryColor, size: 28),
                SizedBox(width: 12),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _buildSettingsTile(
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'Manage notification preferences',
              color: Colors.blue,
              onTap: () => _showNotificationSettings(),
            ),
            _buildSettingsTile(
              icon: Icons.security,
              title: 'Privacy & Security',
              subtitle: 'Account security settings',
              color: Colors.green,
              onTap: () => _showSecuritySettings(),
            ),
            _buildSettingsTile(
              icon: Icons.help,
              title: 'Help & Support',
              subtitle: 'Get help and contact support',
              color: Colors.orange,
              onTap: () => _showHelpSupport(),
            ),
            SizedBox(height: 20),
            _buildLogoutButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red, Colors.red.shade600],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLogoutDialog(context),
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedInfoTile({
    required IconData icon,
    required String title,
    required String value,
    TextEditingController? controller,
    bool isEditable = false,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.1),
                  Theme.of(context).primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: Theme.of(context).primaryColor),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 4),
                if (_isEditing && isEditable && controller != null)
                  TextField(
                    controller: controller,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  )
                else
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Colors.grey[200],
      indent: 61,
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper methods for payment methods
  IconData _getPaymentMethodIcon(String type) {
    switch (type) {
      case 'visa':
      case 'mastercard':
        return Icons.credit_card;
      case 'paypal':
        return Icons.account_balance_wallet;
      case 'bank':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  Color _getPaymentMethodColor(String type) {
    switch (type) {
      case 'visa':
        return Colors.blue;
      case 'mastercard':
        return Colors.red;
      case 'paypal':
        return Colors.indigo;
      case 'bank':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentMethodName(String type) {
    switch (type) {
      case 'visa':
        return 'Visa Card';
      case 'mastercard':
        return 'Mastercard';
      case 'paypal':
        return 'PayPal';
      case 'bank':
        return 'Bank Account';
      default:
        return 'Payment Method';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Action methods
  void _toggleEditMode() async {
    if (_isEditing) {
      // Save changes
      await _saveProfileChanges();
    }
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveProfileChanges() async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Saving changes...'),
            ],
          ),
          backgroundColor: Colors.blue,
        ),
      );

      // TODO: Implement actual API call to update user profile
      await Future.delayed(Duration(seconds: 1)); // Simulate API call

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Profile updated successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddPaymentMethod() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddPaymentMethodSheet(),
    );
  }

  Widget _buildAddPaymentMethodSheet() {
    final cardNumberController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    final nameController = TextEditingController();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Add Payment Method',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 24),
            TextField(
              controller: cardNumberController,
              decoration: InputDecoration(
                labelText: 'Card Number',
                prefixIcon: Icon(Icons.credit_card),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: '1234 5678 9012 3456',
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: expiryController,
                    decoration: InputDecoration(
                      labelText: 'MM/YY',
                      prefixIcon: Icon(Icons.date_range),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      hintText: '12/25',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: cvvController,
                    decoration: InputDecoration(
                      labelText: 'CVV',
                      prefixIcon: Icon(Icons.security),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      hintText: '123',
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Cardholder Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'John Doe',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _addPaymentMethod(cardNumberController.text);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Add Card'),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  void _addPaymentMethod(String cardNumber) {
    if (cardNumber.isNotEmpty) {
      setState(() {
        _paymentMethods.add(PaymentMethod(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'visa',
          lastFour: cardNumber.substring(cardNumber.length - 4),
          isDefault: _paymentMethods.isEmpty,
        ));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment method added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showTransactionHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionHistoryScreen(transactions: _transactions),
      ),
    );
  }

  void _showAppSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppSettingsScreen(),
      ),
    );
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildNotificationSettingsSheet(),
    );
  }

  Widget _buildNotificationSettingsSheet() {
    bool pushNotifications = true;
    bool emailNotifications = false;
    bool smsNotifications = true;

    return StatefulBuilder(
      builder: (context, setModalState) => Container(
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Notification Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(height: 24),
              SwitchListTile(
                title: Text('Push Notifications'),
                subtitle: Text('Receive notifications on your device'),
                value: pushNotifications,
                onChanged: (value) => setModalState(() => pushNotifications = value),
                secondary: Icon(Icons.notifications, color: Theme.of(context).primaryColor),
              ),
              SwitchListTile(
                title: Text('Email Notifications'),
                subtitle: Text('Receive notifications via email'),
                value: emailNotifications,
                onChanged: (value) => setModalState(() => emailNotifications = value),
                secondary: Icon(Icons.email, color: Theme.of(context).primaryColor),
              ),
              SwitchListTile(
                title: Text('SMS Notifications'),
                subtitle: Text('Receive notifications via SMS'),
                value: smsNotifications,
                onChanged: (value) => setModalState(() => smsNotifications = value),
                secondary: Icon(Icons.sms, color: Theme.of(context).primaryColor),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Notification settings saved!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Save Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSecuritySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSecuritySettingsSheet(),
    );
  }

  Widget _buildSecuritySettingsSheet() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Privacy & Security',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 24),
            ListTile(
              leading: Icon(Icons.lock, color: Colors.orange),
              title: Text('Change Password'),
              subtitle: Text('Update your account password'),
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showChangePasswordDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.fingerprint, color: Colors.green),
              title: Text('Biometric Authentication'),
              subtitle: Text('Enable fingerprint/face unlock'),
              trailing: Switch(
                value: true,
                onChanged: (value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Biometric setting updated')),
                  );
                },
              ),
            ),
            ListTile(
              leading: Icon(Icons.visibility_off, color: Colors.blue),
              title: Text('Privacy Settings'),
              subtitle: Text('Control who can see your information'),
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Privacy settings feature coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              obscureText: true,
            ),
            SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              obscureText: true,
            ),
            SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Password updated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showHelpSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HelpSupportScreen(),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.logout, color: Colors.red),
            ),
            SizedBox(width: 12),
            Text('Confirm Logout'),
          ],
        ),
        content: Text(
          'Are you sure you want to logout from your account?',
          style: TextStyle(fontSize: 16),
        ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// Data Models
class PaymentMethod {
  final String id;
  final String type; // visa, mastercard, paypal, bank
  final String? lastFour;
  final String? email;
  final bool isDefault;

  PaymentMethod({
    required this.id,
    required this.type,
    this.lastFour,
    this.email,
    required this.isDefault,
  });
}

class Transaction {
  final String id;
  final double amount;
  final String type; // received, sent
  final String description;
  final DateTime date;
  final String status; // completed, pending, failed

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    required this.date,
    required this.status,
  });
}

// Additional Screens
class TransactionHistoryScreen extends StatelessWidget {
  final List<Transaction> transactions;

  const TransactionHistoryScreen({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transaction History'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          final isReceived = transaction.type == 'received';
          final color = isReceived ? Colors.green : Colors.red;
          
          return Card(
            margin: EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isReceived ? Icons.arrow_downward : Icons.arrow_upward,
                  color: color,
                ),
              ),
              title: Text(transaction.description),
              subtitle: Text(
                '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isReceived ? '+' : '-'}\${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: transaction.status == 'completed' ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      transaction.status.toUpperCase(),
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AppSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App Settings'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.dark_mode, color: Colors.indigo),
                title: Text('Dark Mode'),
                trailing: Switch(
                  value: false,
                  onChanged: (value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Dark mode feature coming soon!')),
                    );
                  },
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.language, color: Colors.green),
                title: Text('Language'),
                subtitle: Text('English'),
                trailing: Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Language selection coming soon!')),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.location_on, color: Colors.red),
                title: Text('Location Services'),
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Location setting updated')),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HelpSupportScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Help & Support'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.help, color: Colors.blue),
                title: Text('FAQ'),
                subtitle: Text('Frequently asked questions'),
                trailing: Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('FAQ section coming soon!')),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.support_agent, color: Colors.green),
                title: Text('Contact Support'),
                subtitle: Text('Get help from our team'),
                trailing: Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Contact support feature coming soon!')),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.bug_report, color: Colors.orange),
                title: Text('Report a Bug'),
                subtitle: Text('Help us improve the app'),
                trailing: Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Bug report feature coming soon!')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}