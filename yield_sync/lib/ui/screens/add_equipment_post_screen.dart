import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../services/labour_equipment_post_service.dart';
import '../../services/nav.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

class AddEquipmentPostScreen extends StatefulWidget {
  const AddEquipmentPostScreen({super.key});

  @override
  State<AddEquipmentPostScreen> createState() => _AddEquipmentPostScreenState();
}

class _AddEquipmentPostScreenState extends State<AddEquipmentPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _equipmentTypeCtrl = TextEditingController();
  final _forCropCtrl = TextEditingController();
  final _nearestDistrictCtrl = TextEditingController();
  final _seasonCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  final _availableDayCtrl = TextEditingController();
  final _availableTimeCtrl = TextEditingController();
  final _hourlyRateCtrl = TextEditingController();
  final _dailyRateCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _ownerContactCtrl = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _equipmentTypeCtrl.dispose();
    _forCropCtrl.dispose();
    _nearestDistrictCtrl.dispose();
    _seasonCtrl.dispose();
    _conditionCtrl.dispose();
    _availableDayCtrl.dispose();
    _availableTimeCtrl.dispose();
    _hourlyRateCtrl.dispose();
    _dailyRateCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerContactCtrl.dispose();
    super.dispose();
  }

  String? _req(String? v, String msg) {
    if (v == null || v.trim().isEmpty) return msg;
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final hourly = double.tryParse(_hourlyRateCtrl.text.trim()) ?? 0.0;
      final daily = double.tryParse(_dailyRateCtrl.text.trim()) ?? 0.0;
      if (hourly <= 0 && daily <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter hourly or daily rate (LKR)')),
        );
        setState(() => _saving = false);
        return;
      }

      await LabourEquipmentPostService.createEquipmentPost(
        equipmentType: _equipmentTypeCtrl.text.trim(),
        forCrop: _forCropCtrl.text.trim(),
        nearestMajorDistrict: _nearestDistrictCtrl.text.trim(),
        season: _seasonCtrl.text.trim(),
        condition: _conditionCtrl.text.trim(),
        availableDay: _availableDayCtrl.text.trim(),
        availableTime: _availableTimeCtrl.text.trim(),
        hourlyRateLkr: hourly > 0 ? hourly : (daily / 8),
        dailyRateLkr: daily > 0 ? daily : (hourly * 8),
        ownerName: _ownerNameCtrl.text.trim(),
        ownerContact: _ownerContactCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipment listed. It will appear in the list.')),
      );
      Nav.back(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Equipment details',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: _equipmentTypeCtrl,
                              label: 'Equipment type',
                              hint: 'e.g. Tractor, Harvester, Sprayer',
                              validator: (v) => _req(v, 'Equipment type required'),
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _forCropCtrl,
                              label: 'For crop',
                              hint: 'e.g. Paddy, Rice',
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _nearestDistrictCtrl,
                              label: 'Nearest district / area',
                              hint: 'e.g. Kurunegala - Town',
                              validator: (v) => _req(v, 'Location required'),
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _seasonCtrl,
                              label: 'Season',
                              hint: 'e.g. Yala, Maha',
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _conditionCtrl,
                              label: 'Condition',
                              hint: 'e.g. Good, Excellent',
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    controller: _availableDayCtrl,
                                    label: 'Available day',
                                    hint: 'e.g. Weekdays',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AppTextField(
                                    controller: _availableTimeCtrl,
                                    label: 'Available time',
                                    hint: 'e.g. 8am-5pm',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _hourlyRateCtrl,
                              label: 'Hourly rate (LKR)',
                              hint: 'e.g. 2000',
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _dailyRateCtrl,
                              label: 'Daily rate (LKR)',
                              hint: 'e.g. 15000',
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _ownerNameCtrl,
                              label: 'Owner name',
                              hint: 'Your name (or leave blank to use profile)',
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _ownerContactCtrl,
                              label: 'Contact number',
                              hint: '07XXXXXXXX',
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 18),
                            PrimaryButton(
                              text: _saving ? 'Adding...' : 'List equipment',
                              icon: _saving ? Icons.hourglass_top_rounded : Icons.add_business_rounded,
                              onPressed: _saving ? null : _submit,
                              isLoading: _saving,
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
    );
  }

  Widget _header() {
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
            onPressed: () => Nav.back(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'List equipment for hire',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
