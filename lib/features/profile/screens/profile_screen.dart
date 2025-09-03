import 'package:emergency_map_sy/features/auth/cubit/auth_cubit.dart';
import 'package:emergency_map_sy/features/profile/cubit/profile_cubit.dart';
import 'package:emergency_map_sy/features/auth/screens/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileCubit()..fetchProfile(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Profile'),
        ),
        body: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            if (state is ProfileLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ProfileError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${state.message}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<ProfileCubit>().fetchProfile(),
                      child: const Text('Retry'),
                    )
                  ],
                ),
              );
            }
            if (state is ProfileLoaded) {
              final profile = state.userProfile;
              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildProfileHeader(profile),
                    _buildRoleSpecificContent(profile),
                    _buildContactInfo(profile, context),
                    _buildLocationInfo(profile, context),
                    if (profile.hasResponderSpecialization) _buildResponderInfo(profile),
                    if (profile.pendingRequestsCount > 0) _buildRequestsInfo(profile),
                    const SizedBox(height: 24),
                    _buildActionButtons(context),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(profile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getRoleColor(profile.primaryRole).withOpacity(0.1),
            _getRoleColor(profile.primaryRole).withOpacity(0.05),
          ],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: _getRoleColor(profile.primaryRole),
                backgroundImage: profile.profileImage?.publicPath != null
                    ? NetworkImage(profile.profileImage!.publicPath)
                    : null,
                child: profile.profileImage == null
                    ? Text(
                        profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getRoleColor(profile.primaryRole),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getRoleIcon(profile.primaryRole),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            profile.name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getRoleColor(profile.primaryRole),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              profile.primaryRole.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          if (profile.roles.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: profile.roles
                  .where((role) => role != profile.primaryRole.toLowerCase())
                  .map<Widget>((role) => Chip(
                        label: Text(
                          role.toUpperCase(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: Colors.grey.shade200,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleSpecificContent(profile) {
    switch (profile.primaryRole) {
      case 'Citizen':
        return _buildCitizenContent(profile);
      case 'Responder':
        return _buildResponderContent(profile);
      case 'Coordinator':
        return _buildCoordinatorContent(profile);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCitizenContent(profile) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: Colors.green.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Citizen Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'You can report emergencies and receive assistance from emergency responders in your area.',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildResponderContent(profile) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medical_services,
                color: Colors.blue.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Emergency Responder',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'You respond to emergency calls and provide assistance to citizens in need. You can view and accept emergency assignments.',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinatorContent(profile) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                color: Colors.purple.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Emergency Coordinator',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'You coordinate emergency response operations, manage resources, and oversee responder assignments.',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(profile, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Contact Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.phone,
                title: 'Phone Number',
                value: profile.phoneNumber,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: profile.phoneNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Phone number copied to clipboard')),
                  );
                },
              ),
              if (profile.authPhone?.isVerified == true) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.verified,
                      color: Colors.green.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Verified ${profile.authPhone?.verifiedAt ?? ''}',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInfo(profile, BuildContext context) {
    if (!profile.hasLocation) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Location',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.location_on,
                title: 'Address',
                value: profile.location!.address,
                onTap: () {
                  // Could open maps or copy address
                  Clipboard.setData(ClipboardData(text: profile.location!.address));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponderInfo(profile) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Specialization',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.local_hospital,
                title: 'Type',
                value: profile.responderType!.description,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsInfo(profile) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        color: Colors.orange.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.assignment_late,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Pending Requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'You have ${profile.pendingRequestsCount} pending participation request(s)',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Profile'),
              onPressed: () => context.read<ProfileCubit>().fetchProfile(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              onPressed: () {
                context.read<AuthCubit>().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.copy,
              color: Colors.grey.shade400,
              size: 16,
            ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'coordinator':
        return Colors.purple;
      case 'responder':
        return Colors.blue;
      case 'citizen':
        return Colors.green;
      case 'ai agent':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'coordinator':
        return Icons.admin_panel_settings;
      case 'responder':
        return Icons.medical_services;
      case 'citizen':
        return Icons.person;
      case 'ai agent':
        return Icons.smart_toy;
      default:
        return Icons.help;
    }
  }
}
