import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../services/app_routes.dart';
import '../widgets/app_shell.dart';
import '../../services/labor_api.dart';
import '../../services/recommendation_api.dart';
import 'labor_hire_screen.dart';

class LaborListScreen extends StatefulWidget {
  const LaborListScreen({super.key});

  @override
  State<LaborListScreen> createState() => _LaborListScreenState();
}

class _LaborListScreenState extends State<LaborListScreen> {
  final _searchCtrl = TextEditingController();
  late LaborSearchArgs _args;

  /// When true: recommendation + semantic search. When false: normal keyword/name search.
  bool _useSemanticSearch = true;

  bool _loading = false;
  String? _error;
  List<LaborWorker> _items = [];
  String? _primaryLocationFromQuery;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final a = ModalRoute.of(context)?.settings.arguments;
    _args = (a is LaborSearchArgs)
        ? a
        : LaborSearchArgs(query: "", location: "Kurunegala", skill: null);

    _searchCtrl.text = _args.query;
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final q = _searchCtrl.text.trim();
      _primaryLocationFromQuery = _extractLocationFromQuery(q);

      List<LaborWorker> list;

      if (_useSemanticSearch) {
        // Recommendation + semantic search (current behavior)
        final parts = <String>[];
        if (q.isNotEmpty) parts.add(q);
        if (_args.skill != null && _args.skill!.trim().isNotEmpty) {
          parts.add(_args.skill!.trim());
        }
        if (_args.location.trim().isNotEmpty) {
          parts.add('in ${_args.location.trim()}');
        }
        final composedQuery = parts.join(' ').trim();

        final recs = await RecommendationApi.recommendLabour(
          query: composedQuery.isEmpty ? _args.location : composedQuery,
          topK: 40,
        );
        list = recs.map((e) => LaborWorker.fromJson(e)).toList();
      } else {
        // Normal keyword/name search
        final map = await LaborApi.search(
          query: q,
          location: _args.location,
          skill: _args.skill,
          topK: 40,
        );
        final rawItems = map['items'] as List<dynamic>? ?? [];
        list = rawItems
            .map((e) =>
                LaborWorker.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearSearch() {
    setState(() => _searchCtrl.clear());
    _fetch();
  }

  String? _extractLocationFromQuery(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return null;
    final exp = RegExp(r'\bin\s+([A-Za-z\s]+)$', caseSensitive: false);
    final m = exp.firstMatch(q);
    if (m == null) return null;
    final loc = m.group(1)?.trim();
    if (loc == null || loc.isEmpty) return null;
    return loc;
  }

  @override
  Widget build(BuildContext context) {
    final list = _items;
    final primaryKey = _primaryLocationFromQuery?.toLowerCase().trim();

    List<LaborWorker> primary = list;
    List<LaborWorker> others = const [];

    if (primaryKey != null && primaryKey.isNotEmpty) {
      primary = list
          .where((w) =>
              w.location.toLowerCase().contains(primaryKey))
          .toList();
      others = list
          .where((w) =>
              !w.location.toLowerCase().contains(primaryKey))
          .toList();
    }

    return AppShell(
      currentIndex: 0,
      child: Column(
        children: [
          _heroHeader(list.length),
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                    children: [
                      _searchCard(),
                      const SizedBox(height: 12),
                      if (_loading) ...[
                        _skeletonCard(),
                        const SizedBox(height: 12),
                        _skeletonCard(),
                        const SizedBox(height: 12),
                        _skeletonCard(),
                      ] else if (_error != null) ...[
                        _errorBox(_error!, onRetry: _fetch),
                      ] else if (list.isEmpty) ...[
                        _emptyBox(
                          title: "No workers found",
                          subtitle:
                              "Try different keyword or change filters in the previous screen.",
                          onRetry: _fetch,
                        ),
                      ] else ...[
                        // Primary location results first (if any)
                        ...primary.map((w) => _WorkerCardModern(
                              worker: w,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.laborDetails,
                                  arguments: w,
                                );
                              },
                            )),
                        if (primary.isNotEmpty && others.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.45),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: const [
                                Expanded(
                                  child: Divider(
                                    color: AppColors.border,
                                    thickness: 1,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Icon(
                                  Icons.location_city_rounded,
                                  size: 16,
                                  color: AppColors.darkGreen,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "Other locations",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textDark,
                                    fontSize: 12.5,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Divider(
                                    color: AppColors.border,
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        // Other locations under the separator
                        ...others.map((w) => _WorkerCardModern(
                              worker: w,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.laborDetails,
                                  arguments: w,
                                );
                              },
                            )),
                      ],
                    ],
                  ),
                ),

                // Sticky bottom info/CTA
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: SafeArea(
                    top: false,
                    child: _stickyFooter(list.length),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= HERO =================
  Widget _heroHeader(int count) {
    final skillLabel = (_args.skill == null || _args.skill!.trim().isEmpty)
        ? "Any skill"
        : _args.skill!.trim();

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
      child: Column(
        children: [
          Row(
            children: [
              _roundIconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Available Workers",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              _roundIconBtn(
                icon: Icons.refresh_rounded,
                onTap: _fetch,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _args.location,
              style: TextStyle(
                color: Colors.white.withOpacity(0.97),
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "$count workers • Skill: $skillLabel",
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontWeight: FontWeight.w600,
                fontSize: 12.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _headerChip(
                icon: Icons.location_on_rounded,
                label: _args.location,
              ),
              _headerChip(
                icon: Icons.badge_rounded,
                label: skillLabel,
              ),
              _headerChip(
                icon: Icons.people_alt_rounded,
                label: "$count",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.95)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontWeight: FontWeight.w800,
                fontSize: 12.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundIconBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white.withOpacity(0.14),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  // ================= SEARCH CARD =================
  Widget _searchCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              const Text(
                "Search",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  fontSize: 14.5,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _useSemanticSearch ? "Smart" : "Name",
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textDark.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: _useSemanticSearch,
                    onChanged: (v) {
                      setState(() => _useSemanticSearch = v);
                      _fetch();
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              if (_loading)
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _useSemanticSearch
                ? "Semantic: e.g. field worker below 1500"
                : "Keyword: e.g. name, harvesting, weeding",
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textDark.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            onSubmitted: (_) => _fetch(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: "Type & press Enter (name, harvesting, weeding...)",
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchCtrl.text.trim().isNotEmpty)
                    IconButton(
                      tooltip: "Clear",
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  IconButton(
                    tooltip: "Refresh",
                    onPressed: _fetch,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.6),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // ================= Sticky footer =================
  Widget _stickyFooter(int count) {
    final skillTxt = (_args.skill == null || _args.skill!.trim().isEmpty)
        ? "Any skill"
        : _args.skill!.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "$count results • ${_args.location} • $skillTxt",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textDark.withOpacity(0.75),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.tune_rounded),
              label: const Text(
                "Filters",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.darkGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= Empty / Error / Skeleton =================
  Widget _emptyBox({
    required String title,
    required String subtitle,
    required VoidCallback onRetry,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppColors.textDark,
              )),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark.withOpacity(0.60),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                "Retry",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.darkGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _errorBox(String message, {required VoidCallback onRetry}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Error loading workers",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.red.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                "Retry",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.darkGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _skeletonCard() {
    Widget bar({double w = double.infinity, double h = 12}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(w: 160, h: 14),
                const SizedBox(height: 10),
                bar(w: 220),
                const SizedBox(height: 10),
                Row(
                  children: [
                    bar(w: 80, h: 26),
                    const SizedBox(width: 10),
                    bar(w: 90, h: 26),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= Modern Worker Card =================
class _WorkerCardModern extends StatelessWidget {
  final LaborWorker worker;
  final VoidCallback onTap;

  const _WorkerCardModern({required this.worker, required this.onTap});

  String _initials(String name) {
    final n = name.trim();
    if (n.isEmpty) return "W";
    final parts = n.split(" ").where((e) => e.trim().isNotEmpty).toList();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
  }

  Color _scoreColor(double s) {
    if (s >= 0.75) return const Color(0xFF2FA36B);
    if (s >= 0.5) return const Color(0xFFC9A80B);
    return const Color(0xFFE05C5C);
  }

  @override
  Widget build(BuildContext context) {
    final score = worker.score;
    final scorePct =
        (score <= 1.0) ? (score * 100) : score; // supports 0-1 or 0-100
    final scColor = _scoreColor(score <= 1.0 ? score : (score / 100.0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withOpacity(0.16),
                      child: Text(
                        _initials(worker.name),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            worker.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15.5,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 16, color: AppColors.darkGreen),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  worker.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark.withOpacity(0.65),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "LKR ${worker.hourlyRate.toStringAsFixed(0)}/hr",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.darkGreen,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: scColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                            border:
                                Border.all(color: scColor.withOpacity(0.25)),
                          ),
                          child: Text(
                            "Match ${scorePct.toStringAsFixed(0)}%",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: scColor,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < worker.rating.round()
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 18,
                        color: const Color(0xFFF5B400),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      worker.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        worker.labourType,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.darkGreen,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip("Skill: ${worker.skillLevel}"),
                    _chip("Crop: ${worker.cropType}"),
                    _chip("Exp: ${worker.experienceYears}y"),
                    _chip("Jobs: ${worker.jobsCompleted}"),
                    if (worker.availableDay.isNotEmpty ||
                        worker.availableTime.isNotEmpty)
                      _chip(
                          "Avail: ${worker.availableDay} ${worker.availableTime}"
                              .trim()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        s,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.textDark.withOpacity(0.75),
          fontSize: 12,
        ),
      ),
    );
  }
}

// ===== Model from backend JSON (unchanged) =====
class LaborWorker {
  final String id;
  final String name;
  final String location;
  final String labourType;
  final String skillLevel;
  final double hourlyRate;
  final double rating;
  final int experienceYears;
  final int jobsCompleted;
  final String season;
  final String cropType;
  final String availableDay;
  final String availableTime;
  final double score;

  LaborWorker({
    required this.id,
    required this.name,
    required this.location,
    required this.labourType,
    required this.skillLevel,
    required this.hourlyRate,
    required this.rating,
    required this.experienceYears,
    required this.jobsCompleted,
    required this.season,
    required this.cropType,
    required this.availableDay,
    required this.availableTime,
    required this.score,
  });

  factory LaborWorker.fromJson(Map m) {
    double _d(v) =>
        (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    int _i(v) => (v is num) ? v.toInt() : int.tryParse(v.toString()) ?? 0;

    return LaborWorker(
      // Support both /api/labour/search (lowercase keys)
      // and /api/recommend/recommend (DataFrame column-style keys).
      id: (m["id"] ?? m["Labour_ID"] ?? "").toString(),
      name: (m["name"] ?? m["Name"] ?? "").toString(),
      location: (m["location"] ?? m["Location"] ?? "").toString(),
      labourType: (m["labour_type"] ?? m["Labour_Type"] ?? "").toString(),
      skillLevel:
          (m["skill_level"] ?? m["Skill_Level"] ?? "").toString(),
      hourlyRate: _d(m["hourly_rate"] ?? m["Hourly_Rate"]),
      rating: _d(m["rating"] ?? m["Rating"]),
      experienceYears:
          _i(m["experience_years"] ?? m["Experience_Years"]),
      jobsCompleted:
          _i(m["jobs_completed"] ?? m["Jobs_Completed"]),
      season: (m["season"] ?? m["Season"] ?? "").toString(),
      cropType: (m["crop_type"] ?? m["Crop_Type"] ?? "").toString(),
      availableDay:
          (m["available_day"] ?? m["Available_Day"] ?? "").toString(),
      availableTime:
          (m["available_time"] ?? m["Available_Time"] ?? "").toString(),
      score: _d(m["score"]),
    );
  }
}
