import 'package:flutter/material.dart';
import '../features/chat/models/chat_models.dart';

class UserProfileModal extends StatelessWidget {
  final ChatUser user;
  final VoidCallback? onClose;
  final VoidCallback? onMessage;

  const UserProfileModal({
    super.key,
    required this.user,
    this.onClose,
    this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'User Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Profile Avatar
            CircleAvatar(
              radius: 50,
              backgroundImage: user.profileImage != null && user.profileImage!.publicPath.isNotEmpty
                  ? NetworkImage(user.profileImage!.publicPath)
                  : null,
              backgroundColor: _getRoleColor(),
              child: user.profileImage == null || user.profileImage!.publicPath.isEmpty
                  ? Text(
                      user.initials,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            
            // Name
            Text(
              user.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Primary Role Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _getRoleColor(),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getPrimaryRole(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // User Details
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phone Number
                    if (user.authPhone != null)
                      _buildInfoRow(
                        icon: Icons.phone,
                        label: 'Phone',
                        value: user.authPhone!.phoneNumber,
                      ),
                    
                    // All Roles
                    if (user.roles.isNotEmpty)
                      _buildInfoRow(
                        icon: Icons.security,
                        label: 'Roles',
                        value: user.roles.join(', '),
                      ),
                    
                    // Responder Type
                    if (user.responderType != null)
                      _buildInfoRow(
                        icon: Icons.local_hospital,
                        label: 'Specialization',
                        value: user.responderType!.description,
                      ),
                    
                    // Location
                    if (user.location != null)
                      _buildInfoRow(
                        icon: Icons.location_on,
                        label: 'Location',
                        value: user.location!.address,
                      ),
                    
                    // Email (if available)
                    if (user.email != null && user.email!.isNotEmpty)
                      _buildInfoRow(
                        icon: Icons.email,
                        label: 'Email',
                        value: user.email!,
                      ),
                    
                    // Participation Requests Count
                    if (user.participationRequests.isNotEmpty)
                      _buildInfoRow(
                        icon: Icons.assignment,
                        label: 'Active Requests',
                        value: '${user.participationRequests.where((r) => r.isPending).length} pending',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (onMessage != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onMessage,
                      icon: const Icon(Icons.message, size: 18),
                      label: const Text('Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (onMessage != null) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Close'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor() {
    if (user.roles.contains('coordinator')) return Colors.purple;
    if (user.roles.contains('responder')) return Colors.blue;
    if (user.roles.contains('citizen')) return Colors.green;
    if (user.roles.contains('ai-agent')) return Colors.orange;
    return Colors.grey;
  }

  String _getPrimaryRole() {
    if (user.roles.contains('coordinator')) return 'Coordinator';
    if (user.roles.contains('responder')) return 'Responder';
    if (user.roles.contains('citizen')) return 'Citizen';
    if (user.roles.contains('ai-agent')) return 'AI Agent';
    return 'Unknown';
  }
}

// Helper function to show user profile modal
void showUserProfile(
  BuildContext context, {
  required ChatUser user,
  VoidCallback? onMessage,
}) {
  showDialog(
    context: context,
    builder: (context) => UserProfileModal(
      user: user,
      onMessage: onMessage,
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}