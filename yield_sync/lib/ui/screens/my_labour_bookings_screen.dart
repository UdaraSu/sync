import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import '../../services/booking_service.dart';
import '../widgets/app_shell.dart';
import 'booking_labour_details_screen.dart';

class MyLabourBookingsScreen extends StatelessWidget {
  const MyLabourBookingsScreen({super.key});

  static Color _statusColor(String s) {
    switch (s) {
      case "accepted":
        return const Color(0xFF15B77E);
      case "rejected":
        return const Color(0xFFE25555);
      case "cancelled":
        return const Color(0xFFF29B38);
      case "completed":
        return const Color(0xFF2BB3D1);
      default:
        return const Color(0xFF6B7C77);
    }
  }

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
                  stream: BookingService.myBookings(),
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
                    final docs = (snap.data?.docs ?? []).toList();
                    docs.sort((a, b) {
                      final at = a.data()["createdAt"];
                      final bt = b.data()["createdAt"];
                      final ad = (at is Timestamp) ? at.toDate() : DateTime(0);
                      final bd = (bt is Timestamp) ? bt.toDate() : DateTime(0);
                      return bd.compareTo(ad);
                    });
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 64, color: AppColors.textDark.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(
                              "No labour bookings yet",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark.withOpacity(0.65),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Book from Hire Labour",
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
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i];
                        final m = d.data();
                        final status = (m["status"] ?? "pending").toString();
                        final labourId = (m["labourId"] ?? "").toString();
                        final start = (m["startDate"] ?? "").toString();
                        final end = (m["endDate"] ?? "").toString();
                        final type = (m["type"] ?? "").toString();
                        final labourUid = (m["labourUid"] ?? "").toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _BookingCard(
                            title: "Labour: $labourId",
                            status: status,
                            start: start,
                            end: end,
                            type: type,
                            statusColor: _statusColor(status),
                            onCancel: status == "pending"
                                ? () async {
                                    await BookingService.updateStatus(
                                      bookingId: d.id,
                                      status: "cancelled",
                                    );
                                  }
                                : null,
                            acceptedHint: "Tap to view details",
                            onTap: status == "accepted"
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BookingLabourDetailsScreen(
                                          labourId: labourId,
                                          labourUid: labourUid,
                                          startDate: start,
                                          endDate: end,
                                          type: type,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
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
                  "Your labour bookings",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "Bookings you made",
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

class _BookingCard extends StatelessWidget {
  final String title;
  final String status;
  final String start;
  final String end;
  final String type;
  final Color statusColor;
  final VoidCallback? onCancel;
  final String acceptedHint;
  final VoidCallback? onTap;

  const _BookingCard({
    required this.title,
    required this.status,
    required this.start,
    required this.end,
    required this.type,
    required this.statusColor,
    this.onCancel,
    required this.acceptedHint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusColor.withOpacity(0.25)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.date_range_rounded,
                      size: 16, color: AppColors.textDark.withOpacity(0.70)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "$start → $end",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark.withOpacity(0.78),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.category_rounded,
                      size: 16, color: AppColors.textDark.withOpacity(0.70)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type.isEmpty ? "—" : type,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark.withOpacity(0.78),
                      ),
                    ),
                  ),
                  if (onCancel != null)
                    TextButton(
                      onPressed: onCancel,
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              if (status == "accepted") ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_rounded,
                          size: 18, color: AppColors.darkGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          acceptedHint,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
