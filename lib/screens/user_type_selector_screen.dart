// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import '../features/auth/models/user_type.dart';
// import '../features/auth/screens/login/login_screen.dart';
// import '../features/auth/cubit/auth_cubit.dart'; // make sure this path matches

// class UserTypeSelectorScreen extends StatelessWidget {
//   const UserTypeSelectorScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [Color(0xFFFFF5F5), Color(0xFFFFEBEE)],
//           ),
//         ),
//         child: SafeArea(
//           child: Stack(
//             children: [
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     // Logo and Title
//                     Container(
//                       width: 80,
//                       height: 80,
//                       decoration: const BoxDecoration(
//                         color: Colors.red,
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(
//                         Icons.security,
//                         color: Colors.white,
//                         size: 40,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     const Text(
//                       'SafetyConnect',
//                       style: TextStyle(
//                         fontSize: 28,
//                         fontWeight: FontWeight.bold,
//                         color: Color(0xFFB71C1C),
//                       ),
//                     ),
//                     const Text(
//                       'Emergency Reporting & Safety System',
//                       style: TextStyle(
//                         fontSize: 16,
//                         color: Color(0xFFD32F2F),
//                       ),
//                     ),
//                     const SizedBox(height: 48),

//                     // User Type Cards
//                     Expanded(
//                       child: Column(
//                         children: [
//                           _buildUserTypeCard(
//                             context,
//                             UserType.citizen,
//                             'I\'m a Citizen',
//                             'Report emergencies and view incidents',
//                             Icons.people,
//                             Colors.blue,
//                           ),
//                           const SizedBox(height: 16),
//                           _buildUserTypeCard(
//                             context,
//                             UserType.responder,
//                             'I\'m a Responder',
//                             'Police, Fire, Medical, or Volunteer',
//                             Icons.security,
//                             Colors.red,
//                           ),
//                           const SizedBox(height: 16),
//                           _buildUserTypeCard(
//                             context,
//                             UserType.coordinator,
//                             'I\'m a Coordinator',
//                             'Emergency Operations Center Staff',
//                             Icons.settings,
//                             Colors.green,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               // 🔴 Hidden Developer Button (top-right corner)
//               Positioned(
//                 top: 8,
//                 right: 8,
//                 child: GestureDetector(
//                   onLongPress: () {
//                     context.read<AuthCubit>().logout();
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(
//                         content: Text("Force logout: tokens cleared ✅"),
//                         duration: Duration(seconds: 2),
//                       ),
//                     );
//                   },
//                   child: Container(
//                     padding: const EdgeInsets.all(6),
//                     decoration: BoxDecoration(
//                       color: Colors.red.withOpacity(0.1), // subtle background
//                       shape: BoxShape.circle,
//                     ),
//                     child: const Icon(
//                       Icons.bug_report,
//                       size: 18,
//                       color: Colors.redAccent,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildUserTypeCard(
//     BuildContext context,
//     UserType userType,
//     String title,
//     String subtitle,
//     IconData icon,
//     Color color,
//   ) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: InkWell(
//         onTap: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => LoginScreen(userType: userType),
//             ),
//           );
//         },
//         borderRadius: BorderRadius.circular(12),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Row(
//             children: [
//               Container(
//                 width: 48,
//                 height: 48,
//                 decoration: BoxDecoration(
//                   color: color.withOpacity(0.1),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(
//                   icon,
//                   color: color,
//                   size: 24,
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.black87,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       subtitle,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         color: Colors.black54,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
