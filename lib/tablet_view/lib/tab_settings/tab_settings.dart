import 'package:flutter/material.dart';
import 'package:print_helper/providers/setting_pro.dart';
import '../tab_utils/regx.dart';
import '../tab_widgets/tab_field_widget.dart';
import '../tab_widgets/tab_image_widget.dart';
import 'package:provider/provider.dart';
import '../tab_constants/paths.dart';
import 'package:print_helper/models/settings_models.dart';
import '../tab_widgets/loaders.dart';
import '../tab_widgets/tab_text_widget.dart';
import '../tab_widgets/tab_spacers.dart';
import '../tab_constants/colors.dart';
import 'tab_file_settings.dart';
import 'tab_twilio_credentials.dart';
import 'tab_contracts_settings.dart';
import 'tab_services_pricing.dart';
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, TextEditingController> _controllers = {};
  int _activeTab = 0;
  final ScrollController _tabScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = Provider.of<SettingsPro>(context, listen: false);
      pro.loadSettings(ctx: context);
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
        automaticallyImplyLeading: false,
        elevation: 2,
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
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: true,
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Image.asset(
                Paths.chatbg,
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(.3),
              ),
            ),
          ),
          Consumer<SettingsPro>(
            builder: (context, pro, _) {
              if (pro.loading) return Center(child: showLoader());
              return SafeArea(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Spacers.sb20(),
                    _topYellowTab(),
                    Expanded(
                      child: _activeTab == 1
                          ? Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: TwilioCredentialsWeb(),
                            )
                          : _activeTab == 2
                          ? const FileSettingsTablet()
                          : _activeTab == 3
                          ? const ContractsSettingsTablet()
                          : _activeTab == 4
                          ? const ServicesPricingSettingsTablet()
                          : Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              color: Colors.white,
                              child: ListView.builder(
                                padding: EdgeInsets.only(
                                  left: 2,
                                  right: 2,
                                  top: 10,
                                ),
                                itemCount: pro.sections.length,
                                itemBuilder: (context, si) {
                                  final section = pro.sections[si];
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
        ],
      ),
    );
  }

  Widget _topYellowTab() {
    return SizedBox(
      height: 35,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 12),
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: .start,
          children: [
            _tabItem("Accounts", index: 0),
            Spacers.sbw10(),
            _tabItem("Twilio", index: 1),
            Spacers.sbw10(),
            _tabItem("File", index: 2),
            Spacers.sbw10(),
            _tabItem("Contracts", index: 3),
            Spacers.sbw10(),
            _tabItem("Services & Pricing", index: 4),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(String title, {required int index}) {
    final bool isActive = _activeTab == index;
    final double itemWidth = 250 + 10;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
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
        width: 250,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.grey.shade300,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
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
      margin: EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .02), blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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
                    width: 150,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
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
                Spacers.sbw30(),
                GestureDetector(
                  onTap: () => Provider.of<SettingsPro>(
                    context,
                    listen: false,
                  ).toggleSection(section.id),
                  child: ImageWidget(
                    image: section.expanded ? Paths.arrowUp : Paths.arrowDwn,
                    width: 20,
                  ),
                ),
                Spacers.sbw20(),
              ],
            ),
          ),
          if (section.expanded)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: pro.isSectionLoading(section.id)
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Spacers.sbw10(),
                            Expanded(
                              flex: 2,
                              child: TextWidget(
                                text: "Item Name",
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Spacers.sbw80(),
                            Spacers.sbw80(),
                            Expanded(
                              flex: 1,
                              child: TextWidget(
                                text: "Date Added",
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Spacer(flex: 5),
                          ],
                        ),
                        Spacers.sb10(),
                        Column(
                          children: [
                            for (final item in section.items)
                              _buildItemRow(
                                section,
                                item,
                                Provider.of<SettingsPro>(
                                  context,
                                  listen: false,
                                ),
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

  String formatCreatedAt(String input) {
    input = input.trim();
    if (input.contains('\n')) {
      final parts = input.split('\n');
      if (parts.length == 2) {
        return "${parts[0]} - ${parts[1]}";
      }
    }
    return input;
  }

  Widget _buildItemRow(
    SettingsSection section,
    SettingsItem item,
    SettingsPro pro,
  ) {
    final ctrl = _getControllerFor(section.id, item);

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 1,
            child: CustomTextField(
              regExpCondition: Regx.addressRegExp,
              controller: ctrl,
              hintText: 'Type ${section.title}',
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

              isDence: true,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            ),
          ),
          Spacers.sbw80(),
          Spacers.sbw80(),
          Expanded(
            flex: 3,
            child: TextWidget(
              text: formatCreatedAt(item.createdAt),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          GestureDetector(
            onTap: () {
              final key = "${section.id}_${item.id}";
              _controllers[key]?.dispose();
              _controllers.remove(key);
              // pro.deleteItem(section.id, item.id);
              if (item.id == 0) {
                // Just remove the temporary unsaved item
                setState(() {
                  section.items.remove(item);
                });
              } else {
                // Database deletion
                pro.deleteItem(section.id, item.id);
              }
            },
            child: Container(
              padding: EdgeInsets.all(6),
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
                onAddPressed(section, name);
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

  void onAddPressed(SettingsSection section, String name) {
    Navigator.pop(context);
    final pro = Provider.of<SettingsPro>(context, listen: false);
    if (section.title.toLowerCase().contains("language")) {
      pro.createLanguage(sectionId: section.id, name: name);
    } else if (section.title.toLowerCase().contains("account")) {
      pro.createAccountType(sectionId: section.id, name: name);
    } else if (section.title.toLowerCase().contains("customer company")) {
      pro.createCustomerCompanyType(sectionId: section.id, name: name);
    } else if (section.title.toLowerCase().contains("customer ranks")) {
      pro.createCustomerRank(sectionId: section.id, name: name);
    } else if (section.title.toLowerCase().contains("skills")) {
      pro.createSkill(sectionId: section.id, name: name);
    } else if (section.title.toLowerCase().contains("client company")) {
      pro.createClientCompanyType(sectionId: section.id, name: name);
    } else if (section.title.toLowerCase().contains("ranks")) {
      pro.createRank(sectionId: section.id, name: name);
    }
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
