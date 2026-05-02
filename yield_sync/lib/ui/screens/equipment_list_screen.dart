import 'dart:async';
import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import '../../utils/equipment_image_asset.dart';
import '../../services/app_routes.dart';
import '../widgets/app_shell.dart';

import '../../services/equipment_api.dart';
import '../../services/recommendation_api.dart';
import 'equipment_rent_screen.dart';

enum _SortMode { best, cheapest, rating }

class EquipmentListScreen extends StatefulWidget {
  const EquipmentListScreen({super.key});

  @override
  State<EquipmentListScreen> createState() => _EquipmentListScreenState();
}

class _EquipmentListScreenState extends State<EquipmentListScreen> {
  final _searchCtrl = TextEditingController();

  late EquipmentSearchArgs _args;

  static const double _equipmentWrapSpacing = 12;

  double _equipmentTileWidth(double rowWidth) =>
      (rowWidth - _equipmentWrapSpacing) / 2;

  /// Two columns with intrinsic row heights (no fixed tile height → no blank strip under short cards).
  Widget _equipmentCardsWrap(List<EquipmentListItem> items) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final tileW = _equipmentTileWidth(constraints.maxWidth);
        return Wrap(
          spacing: _equipmentWrapSpacing,
          runSpacing: _equipmentWrapSpacing,
          children: items
              .map(
                (e) => SizedBox(
                  width: tileW,
                  child: _ModernEquipmentCard(
                    item: e,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.equipmentDetails,
                        arguments: e.id,
                      );
                    },
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  bool _loading = true;
  String? _error;

  List<EquipmentListItem> _items = [];
  List<EquipmentListItem> _view = [];

  Timer? _debounce;

  /// When true: recommendation + semantic. When false: normal keyword search.
  bool _useSemanticSearch = true;

  _SortMode _sort = _SortMode.best;
  String? _primaryLocationFromQuery;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final a = ModalRoute.of(context)?.settings.arguments;
    _args = (a is EquipmentSearchArgs)
        ? a
        : EquipmentSearchArgs(query: "", location: "Kurunegala", type: "");

    _searchCtrl.text = _args.query;

    _fetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
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

      List<EquipmentListItem> list;

      if (_useSemanticSearch) {
        final parts = <String>[];
        if (q.isNotEmpty) parts.add(q);
        if (_args.type.trim().isNotEmpty) {
          parts.add(_args.type.trim());
        }
        if (_args.location.trim().isNotEmpty) {
          parts.add('in ${_args.location.trim()}');
        }
        final composedQuery = parts.join(' ').trim();

        final recs = await RecommendationApi.recommendEquipment(
          query: composedQuery.isEmpty ? _args.location : composedQuery,
          topK: 30,
        );
        list = recs
            .map((e) =>
                EquipmentListItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        list = await EquipmentApi.search(
          query: q,
          location: _args.location,
          type: _args.type,
          topK: 30,
        );
      }

      if (!mounted) return;

      setState(() {
        _items = list;
        _loading = false;
      });

      _applySortAndFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), _fetch);
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

  void _applySortAndFilter() {
    final v = [..._items];

    switch (_sort) {
      case _SortMode.best:
        v.sort((a, b) {
          final sa = (a.rating * 2.2) + (a.pastBookings * 0.04);
          final sb = (b.rating * 2.2) + (b.pastBookings * 0.04);
          return sb.compareTo(sa);
        });
        break;
      case _SortMode.cheapest:
        v.sort((a, b) => a.dailyRate.compareTo(b.dailyRate));
        break;
      case _SortMode.rating:
        v.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }

    setState(() => _view = v);
  }

  String _subTitleText() {
    final typeLabel = _args.type.isEmpty ? "All types" : _args.type;
    final count = _loading ? "…" : "${_items.length}";
    return "${_args.location} • $typeLabel • $count items";
  }

  @override
  Widget build(BuildContext context) {
    final primaryKey = _primaryLocationFromQuery?.toLowerCase().trim();
    final list = _view;

    List<EquipmentListItem> primary = list;
    List<EquipmentListItem> others = const [];

    if (primaryKey != null && primaryKey.isNotEmpty) {
      bool matches(EquipmentListItem e) {
        final loc = (e.nearestMajorDistrict.isNotEmpty
                ? e.nearestMajorDistrict
                : e.location)
            .toLowerCase();
        return loc.contains(primaryKey);
      }

      primary = list.where(matches).toList();
      others = list.where((e) => !matches(e)).toList();
    }

    return AppShell(
      currentIndex: 0,
      child: Column(
        children: [
          // ===== HERO HEADER =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Rent Equipment",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withOpacity(0.12),
                      child:
                          const Icon(Icons.person_rounded, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Available Equipment",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.96),
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _subTitleText(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.22)),
                  ),
                  child: Row(
                    children: [
                      _HeaderPill(
                        icon: Icons.location_on_rounded,
                        text: _args.location,
                      ),
                      const SizedBox(width: 10),
                      _HeaderPill(
                        icon: Icons.category_rounded,
                        text: _args.type.isEmpty ? "All" : _args.type,
                      ),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _fetch,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white.withOpacity(0.16),
                          child: const Icon(Icons.refresh_rounded,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ===== SEARCH + SORT =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _fetch(),
                        decoration: InputDecoration(
                          hintText: _useSemanticSearch
                              ? "e.g. 4wd below 5000"
                              : "e.g. tractor, harvester",
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              _fetch();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                          filled: true,
                          fillColor: Colors.white,
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
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 1.6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _SortButton(
                      mode: _sort,
                      onChanged: (m) {
                        setState(() => _sort = m);
                        _applySortAndFilter();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _useSemanticSearch ? "Smart search" : "Keyword search",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textDark.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
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
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ===== LIST =====
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetch,
              child: _loading
                  ? CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          sliver: SliverToBoxAdapter(
                            child: LayoutBuilder(
                              builder: (_, c) {
                                final tileW =
                                    _equipmentTileWidth(c.maxWidth);
                                return Wrap(
                                  spacing: _equipmentWrapSpacing,
                                  runSpacing: _equipmentWrapSpacing,
                                  children: List.generate(
                                    6,
                                    (_) => SizedBox(
                                      width: tileW,
                                      child: const _SkeletonCard(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    )
                  : _error != null
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                          children: [
                            _ErrorBox(message: _error!, onRetry: _fetch),
                          ],
                        )
                      : _items.isEmpty
                          ? ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 24, 16, 16),
                              children: [
                                _EmptyBox(
                                  title: "No equipment found",
                                  subtitle:
                                      "Try another keyword or select another district/type.",
                                  onRetry: _fetch,
                                ),
                              ],
                            )
                          : CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                if (primary.isNotEmpty)
                                  SliverPadding(
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      others.isNotEmpty ? 0 : 16,
                                    ),
                                    sliver: SliverToBoxAdapter(
                                      child:
                                          _equipmentCardsWrap(primary),
                                    ),
                                  ),
                                if (primary.isNotEmpty &&
                                    others.isNotEmpty)
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 18, 16, 10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: AppColors.primary
                                                .withOpacity(0.45),
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
                                    ),
                                  ),
                                if (others.isNotEmpty)
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 16),
                                    sliver: SliverToBoxAdapter(
                                      child: _equipmentCardsWrap(others),
                                    ),
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

// ===================== MODERN CARD =====================
class _ModernEquipmentCard extends StatelessWidget {
  final EquipmentListItem item;
  final VoidCallback onTap;

  const _ModernEquipmentCard({required this.item, required this.onTap});

  IconData _iconForType(String t) {
    final s = t.toLowerCase();
    if (s.contains("tractor")) return Icons.agriculture_rounded;
    if (s.contains("harvest")) return Icons.grass_rounded;
    if (s.contains("pump") || s.contains("water")) return Icons.water_rounded;
    if (s.contains("spray")) return Icons.water_drop_rounded;
    if (s.contains("plough")) return Icons.handyman_rounded;
    if (s.contains("seed")) return Icons.spa_rounded;
    if (s.contains("trailer")) return Icons.local_shipping_rounded;
    if (s.contains("transplant")) return Icons.eco_rounded;
    return Icons.build_rounded;
  }

  Color _badgeColor(String t) {
    final s = t.toLowerCase();
    if (s.contains("tractor")) return const Color(0xFF2FA36B);
    if (s.contains("harvest")) return const Color(0xFF7B61FF);
    if (s.contains("pump") || s.contains("water")) {
      return const Color(0xFF1C7ED6);
    }
    if (s.contains("spray")) return const Color(0xFFFF922B);
    return const Color(0xFF2D3748);
  }

  @override
  Widget build(BuildContext context) {
    final type = item.equipmentType.isEmpty ? "Equipment" : item.equipmentType;
    final loc = item.nearestMajorDistrict.isNotEmpty
        ? item.nearestMajorDistrict
        : item.location;
    final imageAsset = EquipmentImageAsset.resolve(
      equipmentType: item.equipmentType,
      forCrop: item.forCrop,
      id: item.id,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Photo strip: use contain so whole equipment stays visible (cover was cropping).
              Container(
                height: 142,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          imageAsset,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) =>
                              _fallbackTopVisual(type),
                        ),
                      ),
                      // Bottom scrim so chips stay readable without covering the whole photo.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.06),
                                Colors.black.withOpacity(0.24),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(6, 14, 6, 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.96),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: _badgeColor(type)
                                            .withOpacity(0.28),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.category_rounded,
                                          size: 12,
                                          color: _badgeColor(type),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            type,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 10,
                                              height: 1.12,
                                              color: _badgeColor(type),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.96),
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: AppColors.border),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "LKR ${item.dailyRate.toStringAsFixed(0)}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.darkGreen,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        "day",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark
                                              .withOpacity(0.55),
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // content
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        height: 1.12,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 5),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.location_on_rounded,
                              size: 14, color: AppColors.darkGreen),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            loc,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: AppColors.textDark.withOpacity(0.70),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    Text(
                      "LKR ${item.hourlyRate.toStringAsFixed(0)}/hr",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: AppColors.textDark.withOpacity(0.78),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < item.rating.round()
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 13,
                            color: const Color(0xFFF5B400),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),

                    if (item.condition.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.condition,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          height: 1.15,
                          color: AppColors.textDark.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackTopVisual(String type) {
    return Container(
      color: AppColors.primary.withOpacity(0.10),
      child: Center(
        child: Icon(
          _iconForType(type),
          size: 52,
          color: AppColors.darkGreen.withOpacity(0.86),
        ),
      ),
    );
  }
}

// ===================== SORT BUTTON =====================
class _SortButton extends StatelessWidget {
  final _SortMode mode;
  final ValueChanged<_SortMode> onChanged;

  const _SortButton({required this.mode, required this.onChanged});

  String _label(_SortMode m) {
    switch (m) {
      case _SortMode.best:
        return "Best";
      case _SortMode.cheapest:
        return "Cheap";
      case _SortMode.rating:
        return "Rating";
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortMode>(
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem(
            value: _SortMode.best, child: Text(_label(_SortMode.best))),
        PopupMenuItem(
            value: _SortMode.cheapest, child: Text(_label(_SortMode.cheapest))),
        PopupMenuItem(
            value: _SortMode.rating, child: Text(_label(_SortMode.rating))),
      ],
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.sort_rounded),
            const SizedBox(width: 8),
            Text(
              _label(mode),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textDark.withOpacity(0.55)),
          ],
        ),
      ),
    );
  }
}

// ===================== HEADER PILLS =====================
class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeaderPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.92), size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== SKELETON LOADER =====================
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 142,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              children: [
                _skLine(w: double.infinity, h: 12),
                const SizedBox(height: 8),
                _skLine(w: double.infinity, h: 10),
                const SizedBox(height: 8),
                _skLine(w: 80, h: 10),
                const SizedBox(height: 8),
                _skLine(w: double.infinity, h: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skLine({required double w, required double h}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

// ===================== EMPTY/ERROR =====================
class _EmptyBox extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  const _EmptyBox({
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
          const SizedBox(height: 10),
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
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Error loading equipment",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark.withOpacity(0.60),
            ),
          ),
          const SizedBox(height: 10),
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
}
