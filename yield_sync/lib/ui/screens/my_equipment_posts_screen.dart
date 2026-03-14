import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import '../../services/app_routes.dart';
import '../../services/labour_equipment_post_service.dart';
import '../widgets/app_shell.dart';

class MyEquipmentPostsScreen extends StatelessWidget {
  const MyEquipmentPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentIndex: 0,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: LabourEquipmentPostService.myEquipmentPostsStream(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            "Error: ${snap.error}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
                    sorted.sort((a, b) {
                      final at = a.data()["createdAt"];
                      final bt = b.data()["createdAt"];
                      if (at == null && bt == null) return 0;
                      if (at == null) return 1;
                      if (bt == null) return -1;
                      final ad = (at is Timestamp) ? at.toDate() : DateTime(0);
                      final bd = (bt is Timestamp) ? bt.toDate() : DateTime(0);
                      return bd.compareTo(ad);
                    });
                    if (sorted.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.agriculture_rounded,
                                size: 64, color: AppColors.textDark.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(
                              "No equipment ads yet",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark.withOpacity(0.65),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Add one from the home menu",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: sorted.length,
                      itemBuilder: (context, i) {
                        final d = sorted[i];
                        final m = d.data();
                        final id = (m["Equipment_ID"] ?? m["equipmentId"] ?? d.id).toString();
                        final type = (m["Equipment_Type"] ?? m["equipmentType"] ?? "").toString();
                        final district = (m["Nearest_Major_District"] ?? m["Main_District"] ?? "").toString();
                        final daily = (m["Daily_Rate_LKR"] ?? m["dailyRate"] ?? 0);
                        final dailyRate = (daily is num) ? daily.toDouble() : double.tryParse(daily.toString()) ?? 0.0;
                        return _PostCard(
                          equipmentId: id,
                          equipmentType: type,
                          district: district,
                          dailyRate: dailyRate,
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.equipmentDetails,
                            arguments: id,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded,
                color: Colors.white.withOpacity(0.95)),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your equipment ads",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "Posts you created",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final String equipmentId;
  final String equipmentType;
  final String district;
  final double dailyRate;
  final VoidCallback onTap;

  const _PostCard({
    required this.equipmentId,
    required this.equipmentType,
    required this.district,
    required this.dailyRate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.agriculture_rounded, color: AppColors.darkGreen),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipmentType.isEmpty ? equipmentId : equipmentType,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          fontSize: 15,
                        ),
                      ),
                      if (district.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 14, color: AppColors.textDark.withOpacity(0.5)),
                            const SizedBox(width: 4),
                            Text(
                              district,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark.withOpacity(0.55),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "LKR ${dailyRate.toStringAsFixed(0)}/day",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkGreen,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: AppColors.textDark.withOpacity(0.4)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
