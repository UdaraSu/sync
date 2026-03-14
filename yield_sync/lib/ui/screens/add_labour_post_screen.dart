import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../services/labour_equipment_post_service.dart';
import '../../services/nav.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

class AddLabourPostScreen extends StatefulWidget {
  const AddLabourPostScreen({super.key});

  @override
  State<AddLabourPostScreen> createState() => _AddLabourPostScreenState();
}

class _AddLabourPostScreenState extends State<AddLabourPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _labourTypeCtrl = TextEditingController();
  final _skillLevelCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _seasonCtrl = TextEditingController();
  final _cropTypeCtrl = TextEditingController();
  final _availableDayCtrl = TextEditingController();
  final _availableTimeCtrl = TextEditingController();
  final _hourlyRateCtrl = TextEditingController();
  final _experienceYearsCtrl = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _labourTypeCtrl.dispose();
    _skillLevelCtrl.dispose();
    _locationCtrl.dispose();
    _seasonCtrl.dispose();
    _cropTypeCtrl.dispose();
    _availableDayCtrl.dispose();
    _availableTimeCtrl.dispose();
    _hourlyRateCtrl.dispose();
    _experienceYearsCtrl.dispose();
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
      final hourlyRate = double.tryParse(_hourlyRateCtrl.text.trim()) ?? 0.0;
      final experienceYears = int.tryParse(_experienceYearsCtrl.text.trim()) ?? 0;
      if (hourlyRate <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid hourly rate (LKR)')),
        );
        setState(() => _saving = false);
        return;
      }

      await LabourEquipmentPostService.createLabourPost(
        name: _nameCtrl.text.trim(),
        labourType: _labourTypeCtrl.text.trim(),
        skillLevel: _skillLevelCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        season: _seasonCtrl.text.trim(),
        cropType: _cropTypeCtrl.text.trim(),
        availableDay: _availableDayCtrl.text.trim(),
        availableTime: _availableTimeCtrl.text.trim(),
        hourlyRate: hourlyRate,
        experienceYears: experienceYears,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Labour post added. It will appear in the list.')),
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
                              'Labour details',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: _nameCtrl,
                              label: 'Full name',
                              hint: 'Your name',
                              validator: (v) => _req(v, 'Name required'),
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _labourTypeCtrl,
                              label: 'Labour type / skill',
                              hint: 'e.g. Field Worker, Rice Harvesting',
                              validator: (v) => _req(v, 'Labour type required'),
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _skillLevelCtrl,
                              label: 'Skill level',
                              hint: 'e.g. Experienced, Beginner',
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _locationCtrl,
                              label: 'Location (district / area)',
                              hint: 'e.g. Kurunegala, Pothuhera',
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
                              controller: _cropTypeCtrl,
                              label: 'Crop type',
                              hint: 'e.g. Paddy, Vegetables',
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
                              hint: 'e.g. 500',
                              keyboardType: TextInputType.number,
                              validator: (v) => _req(v, 'Hourly rate required'),
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _experienceYearsCtrl,
                              label: 'Experience (years)',
                              hint: 'e.g. 5',
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 18),
                            PrimaryButton(
                              text: _saving ? 'Adding...' : 'Add labour post',
                              icon: _saving ? Icons.hourglass_top_rounded : Icons.person_add_rounded,
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
              'Add as labour',
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
