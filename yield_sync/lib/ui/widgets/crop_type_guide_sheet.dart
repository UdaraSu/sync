import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/crop_type_guides.dart';
import '../../utils/app_colors.dart';

/// Opens a scrollable sheet with headings, sub-headings, and body copy.
Future<void> showCropTypeGuideSheet(
  BuildContext context,
  CropTypeGuide guide,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9FDF2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textDark.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guide.cropName,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (guide.scientificName != null &&
                              guide.scientificName!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                guide.scientificName!,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      AppColors.textDark.withOpacity(0.55),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textDark.withOpacity(0.65),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                  children: [
                    _sectionHeading("Overview"),
                    const SizedBox(height: 8),
                    _bodyText(guide.overview),
                    const SizedBox(height: 22),
                    _sectionHeading("Growing basics"),
                    const SizedBox(height: 12),
                    ...guide.growingBasics.expand(
                      (b) => [
                        _blockTitle(b.title),
                        const SizedBox(height: 6),
                        _bodyText(b.body),
                        const SizedBox(height: 14),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _sectionHeading("How YieldSync helps"),
                    const SizedBox(height: 12),
                    ...guide.yieldSyncHelps.expand(
                      (b) => [
                        _blockTitle(b.title),
                        const SizedBox(height: 6),
                        _bodyText(b.body),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Widget _sectionHeading(String text) {
  return Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: AppColors.darkGreen,
      height: 1.25,
    ),
  );
}

Widget _blockTitle(String text) {
  return Text(
    text,
    style: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: AppColors.textDark.withOpacity(0.88),
      height: 1.2,
    ),
  );
}

Widget _bodyText(String text) {
  return Text(
    text,
    style: GoogleFonts.inter(
      fontSize: 13.8,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: AppColors.textDark.withOpacity(0.78),
    ),
  );
}
