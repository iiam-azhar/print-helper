// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../models/settings_models.dart';
import '../../providers/setting_pro.dart';
import '../../widgets/text_widget.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/spacers.dart';
import '../../widgets/loaders.dart';
import '../../constants/colors.dart';
import '../../constants/paths.dart';
import 'file_settings.dart';
import 'twilio_settings.dart';
import '../../utils/console_util.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final ScrollController _tabScrollController = ScrollController();
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pro = Provider.of<SettingsPro>(context, listen: false);
      await pro.loadSettings(ctx: context);
    });
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    for (final c in _controllers.values) {
      try {
        c.dispose();
      } catch (_) {}
    }
    _controllers.clear();
    super.dispose();
  }

  TextEditingController _getControllerFor(int sectionId, SettingsItem item) {
    final key = item.localKey;
    if (_controllers.containsKey(key)) return _controllers[key]!;
    final ctrl = TextEditingController(text: item.name);
    _controllers[key] = ctrl;
    ctrl.addListener(() {
      Provider.of<SettingsPro>(
        context,
        listen: false,
      ).updateItemName(sectionId, item.id, ctrl.text);
    });
    return ctrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 2,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ImageWidget(image: Paths.settings, width: 28),
            Spacers.sbw10(),
            TextWidget(
              text: "Settings",
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ],
        ),
      ),
      body: Consumer<SettingsPro>(
        builder: (context, pro, _) {
          if (pro.loading) return Center(child: showLoader());
          if (pro.loading) return Center(child: showLoader());

          List<SettingsSection> filteredSections = [];

          // Debug prints
          printData(title: "Active Tab:", data: _activeTab);
          printData(title: "Total Sections:", data: pro.sections.length);
          for (var s in pro.sections) {
            printData(title: "Section Title:", data: s.title);
          }

          if (_activeTab == 0) {
            // Accounts Tab
            filteredSections = pro.sections.where((s) {
              final title = s.title.toLowerCase();
              return title.contains("account") ||
                  title.contains("client company") ||
                  title.contains("customer company");
            }).toList();
          }
          printData(
            title: "Filtered Sections for Tab $_activeTab:",
            data: filteredSections.length,
          );

          return SafeArea(
            child: Column(
              children: [
                Spacers.sb10(),
                _topYellowTab(),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 0.w,
                      vertical: 0.w,
                    ),
                    color: Colors.white,
                    child: _activeTab == 1
                        ? const TwilioCredentials()
                        : _activeTab == 2
                        ? const FileSettingsMobile()
                        : ListView.builder(
                            padding: EdgeInsets.only(
                              left: 12.w,
                              right: 12.w,
                              top: 10.h,
                            ),
                            itemCount: filteredSections.length,
                            itemBuilder: (context, si) {
                              final section = filteredSections[si];
                              return _buildSection(section, pro);
                            },
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _topYellowTab() {
    return SizedBox(
      height: 35.h,
      child: SingleChildScrollView(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: 15.w, right: 15.w),
        child: Row(
          children: [
            _tabItem("Accounts", index: 0),
            Spacers.sbw10(),
            _tabItem("Twilio", index: 1),
            Spacers.sbw10(),
            _tabItem("File", index: 2),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(String title, {required int index}) {
    final bool isActive = _activeTab == index;
    final double itemWidth = 250.w + 10.w;
    return GestureDetector(
      onTap: () {
        setState(() => _activeTab = index);
        Future.delayed(const Duration(milliseconds: 100), () {
          final position = index * itemWidth;
          if (_tabScrollController.hasClients) {
            _tabScrollController.animateTo(
              position,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      },
      child: Container(
        width: 250.w,
        height: 32.h,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.grey.shade300,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12.r),
            topRight: Radius.circular(12.r),
          ),
        ),
        child: Center(
          child: TextWidget(
            text: title,
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildSection(SettingsSection section, SettingsPro pro) {
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .02), blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextWidget(
                    text: "${section.title} (${section.items.length})",
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Spacers.sbw10(),
                GestureDetector(
                  onTap: () {
                    Provider.of<SettingsPro>(
                      context,
                      listen: false,
                    ).addItem(section.id);
                    setState(() {});
                  },
                  child: Container(
                    width: 110.w,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13.r),
                      border: Border.all(
                        color: const Color(0xFFFFC400),
                        width: 1.6,
                      ),
                    ),
                    child: Center(
                      child: TextWidget(
                        text: "+ Add",
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                Spacers.sbw10(),
                GestureDetector(
                  onTap: () => Provider.of<SettingsPro>(
                    context,
                    listen: false,
                  ).toggleSection(section.id),
                  child: Icon(
                    section.expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ),
              ],
            ),
          ),
          if (section.expanded)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              child: Column(
                children: [
                  Row(
                    children: [
                      Spacers.sbw10(),
                      Expanded(
                        flex: 5,
                        child: TextWidget(
                          text: "Item Name",
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Spacers.sbw10(),
                      Expanded(
                        flex: 3,
                        child: TextWidget(
                          text: "Date Added",
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Spacer(flex: 1),
                    ],
                  ),
                  Spacers.sb10(),
                  Column(
                    children: [
                      for (final item in section.items)
                        _buildItemRow(
                          section,
                          item,
                          Provider.of<SettingsPro>(context, listen: false),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    SettingsSection section,
    SettingsItem item,
    SettingsPro pro,
  ) {
    final ctrl = _getControllerFor(section.id, item);

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- TEXT FIELD ----
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.white,
              ),
              child: TextField(
                controller: ctrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (value) {
                  final typed = value.trim();
                  if (typed.isEmpty) return;
                  final oldName = item.name;
                  if (item.id == 0) {
                    _confirmCreate(section, typed);
                  } else {
                    _confirmUpdate(section, item, oldName, typed);
                  }
                },

                decoration: InputDecoration(
                  hintText: "Type ${section.title}",
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
          Spacers.sbw20(),
          Expanded(
            flex: 1,
            child: TextWidget(
              text: item.createdAt,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          GestureDetector(
            onTap: () {
              final key = "${section.id}_${item.id}";
              _controllers[key]?.dispose();
              _controllers.remove(key);
              pro.deleteItem(section.id, item.id);
            },
            child: Container(
              padding: EdgeInsets.all(6.w),
              child: ImageWidget(image: Paths.delete, width: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCreate(SettingsSection section, String name) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: TextWidget(
            text: "Add ${section.title}",
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          content: TextWidget(
            text: "Do you want to add \"$name\"?",
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const TextWidget(
                text: "Cancel",
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                final pro = Provider.of<SettingsPro>(context, listen: false);
                if (section.title.toLowerCase().contains("language")) {
                  pro.createLanguage(sectionId: section.id, name: name);
                } else if (section.title.toLowerCase().contains("account")) {
                  pro.createAccountType(sectionId: section.id, name: name);
                } else if (section.title.toLowerCase().contains(
                  "customer company",
                )) {
                  pro.createCustomerCompanyType(
                    sectionId: section.id,
                    name: name,
                  );
                } else if (section.title.toLowerCase().contains(
                  "customer ranks",
                )) {
                  pro.createCustomerRank(sectionId: section.id, name: name);
                } else if (section.title.toLowerCase().contains("skills")) {
                  pro.createSkill(sectionId: section.id, name: name);
                } else if (section.title.toLowerCase().contains(
                  "client company",
                )) {
                  pro.createClientCompanyType(
                    sectionId: section.id,
                    name: name,
                  );
                } else if (section.title.toLowerCase().contains("ranks")) {
                  pro.createRank(sectionId: section.id, name: name);
                }
              },
              child: TextWidget(
                text: "Add",
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmUpdate(
    SettingsSection section,
    SettingsItem item,
    String oldName,
    String newName,
  ) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text("Update ${section.title}"),
          content: Text("Do you want to update \"$newName\"?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Provider.of<SettingsPro>(context, listen: false).updateItem(
                  sectionId: section.id,
                  id: item.id,
                  newName: newName,
                );
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }
}
