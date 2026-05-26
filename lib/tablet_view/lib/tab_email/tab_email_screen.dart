import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/providers/email_pro.dart';
import '../../../models/email_models.dart';
import '../tab_constants/colors.dart';
import '../tab_constants/paths.dart';
import '../tab_widgets/tab_image_widget.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/auth_pro.dart';

class TabEmailScreen extends StatefulWidget {
  const TabEmailScreen({super.key});

  @override
  State<TabEmailScreen> createState() => _TabEmailScreenState();
}

class _TabEmailScreenState extends State<TabEmailScreen>
    with WidgetsBindingObserver {
  bool isComposing = false;
  bool showCc = false;
  bool showBcc = false;
  List<Map<String, String>> composeAttachments = [];
  final TextEditingController folderController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _ccController = TextEditingController();
  final TextEditingController _bccController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<String> toEmails = [];
  List<String> ccEmails = [];
  List<String> bccEmails = [];

  final ScrollController _listScrollController = ScrollController();
  Set<String> selectedMessageIds = {};
  int? selectedMoveToFolderId;
  final ScrollController _detailScrollController = ScrollController();

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        for (var file in result.files) {
          double sizeInMb = file.size / (1024 * 1024);
          String sizeStr = sizeInMb < 1.0
              ? '${(file.size / 1024).toStringAsFixed(1)} KB'
              : '${sizeInMb.toStringAsFixed(1)} MB';

          composeAttachments.add({
            'name': file.name,
            'size': sizeStr,
            'path': file.path ?? '',
          });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmailPro>().fetchMailData(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh mail data when user returns to app from browser
      context.read<EmailPro>().fetchMailData(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    folderController.dispose();
    _listScrollController.dispose();
    _detailScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer<EmailPro>(
        builder: (context, emailPro, child) {
          if (emailPro.isLoading && emailPro.emailData == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            );
          }

          if (emailPro.emailData == null) {
            return _buildErrorState(emailPro);
          }

          final bool needsConnect =
              emailPro.emailData!.connectRequired ||
              emailPro.isAddingAccount ||
              emailPro.connectionError != null;

          return Column(
            children: [
              if (!needsConnect) _buildTopAppBar(context, emailPro),
              Expanded(
                child: needsConnect
                    ? _buildConnectionScreen(context, emailPro)
                    : Stack(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Sidebar
                              Container(
                                width: 260,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: Colors.grey.shade100,
                                    ),
                                  ),
                                ),
                                child: _buildSidebar(context, emailPro),
                              ),
                              // Main Content
                              Expanded(
                                child: Container(
                                  color: const Color(0xFFF8F9FA),
                                  child: _buildMainContent(context, emailPro),
                                ),
                              ),
                            ],
                          ),
                          if (isComposing)
                            Positioned(
                              right: 48,
                              bottom: 0,
                              child: _buildComposeBox(),
                            ),
                        ],
                      ),
              ),
              if (!needsConnect && emailPro.selectedMessage == null)
                _buildPagination(emailPro),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComposeBox() {
    return Container(
      width: 500,
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height -
            MediaQuery.of(context).viewInsets.bottom -
            120, // Prevents overflow when keyboard appears
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min, // Allows container to shrink if content is small
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.amber,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "New Message",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          isComposing = false;
                        });
                      },
                      child: const Icon(
                        Icons.minimize_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () {
                        setState(() {
                          isComposing = false;
                        });
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // To
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            "To",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _EmailInputWidget(
                              controller: _toController,
                              emails: toEmails,
                              onChanged: (emails) =>
                                  setState(() => toEmails = emails),
                              hintText: "recipient@example.com",
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!showCc)
                            InkWell(
                              onTap: () => setState(() => showCc = true),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 4.0),
                                child: Text(
                                  "Cc",
                                  style: TextStyle(
                                    color: AppColors.amber.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          if (!showBcc)
                            InkWell(
                              onTap: () => setState(() => showBcc = true),
                              child: Text(
                                "Bcc",
                                style: TextStyle(
                                  color: AppColors.amber.withValues(alpha: 0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (showCc) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              "Cc",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _EmailInputWidget(
                                controller: _ccController,
                                emails: ccEmails,
                                onChanged: (emails) =>
                                    setState(() => ccEmails = emails),
                                hintText: "cc@example.com",
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => showCc = false),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (showBcc) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              "Bcc",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _EmailInputWidget(
                                controller: _bccController,
                                emails: bccEmails,
                                onChanged: (emails) =>
                                    setState(() => bccEmails = emails),
                                hintText: "bcc@example.com",
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => showBcc = false),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Subject
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          hintText: "Subject",
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Message Body
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _bodyController,
                        minLines: 6,
                        maxLines: 15,
                        decoration: const InputDecoration(
                          hintText: "Compose your message",
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),

                    if (composeAttachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "ATTACHMENTS",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    "${composeAttachments.length} file(s)",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                              thickness: 1,
                            ),
                            ...composeAttachments.asMap().entries.map((entry) {
                              int idx = entry.key;
                              var file = entry.value;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.insert_drive_file_outlined,
                                      color: Colors.blueGrey.shade300,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      file['name']!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      file['size']!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          composeAttachments.removeAt(idx);
                                        });
                                      },
                                      child: const ImageWidget(
                                        image: Paths.delete,
                                        color: Colors.red,
                                        height: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Bottom Actions
                    Row(
                      children: [
                        InkWell(
                          onTap: _pickFiles,
                          child: const Icon(
                            Icons.attach_file_rounded,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade200),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            "Save Draft",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            // Push any pending text in controllers to the lists
                            if (_toController.text.trim().isNotEmpty) {
                              toEmails.add(
                                _toController.text.trim().replaceAll(',', ''),
                              );
                              _toController.clear();
                            }
                            if (_ccController.text.trim().isNotEmpty) {
                              ccEmails.add(
                                _ccController.text.trim().replaceAll(',', ''),
                              );
                              _ccController.clear();
                            }
                            if (_bccController.text.trim().isNotEmpty) {
                              bccEmails.add(
                                _bccController.text.trim().replaceAll(',', ''),
                              );
                              _bccController.clear();
                            }

                            if (toEmails.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Please enter at least one recipient.",
                                  ),
                                ),
                              );
                              return;
                            }
                            if (_subjectController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please enter a subject."),
                                ),
                              );
                              return;
                            }

                            final emailProvider = context.read<EmailPro>();
                            emailProvider
                                .sendMail(
                                  context,
                                  to: toEmails.join(','),
                                  cc: ccEmails.join(','),
                                  bcc: bccEmails.join(','),
                                  subject: _subjectController.text.trim(),
                                  body: _bodyController.text.trim(),
                                  attachments: composeAttachments,
                                )
                                .then((success) {
                                  if (success) {
                                    setState(() {
                                      isComposing = false;
                                      toEmails.clear();
                                      ccEmails.clear();
                                      bccEmails.clear();
                                      _toController.clear();
                                      _ccController.clear();
                                      _bccController.clear();
                                      _subjectController.clear();
                                      _bodyController.clear();
                                      composeAttachments.clear();
                                    });
                                  }
                                });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.amber,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            "Send",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(EmailPro emailPro) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Failed to load email data"),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => emailPro.fetchMailData(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber),
            child: const Text("Retry", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, EmailPro emailPro) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSidebarItem(
              Icons.inbox_rounded,
              "Inbox",
              isActive: emailPro.selectedFolder == 'inbox',
              onTap: () => emailPro.setFolder(context, 'inbox'),
            ),
            _buildSidebarItem(
              Icons.send_rounded,
              "Sent",
              isActive: emailPro.selectedFolder == 'sent',
              onTap: () => emailPro.setFolder(context, 'sent'),
            ),
            _buildSidebarItem(
              Icons.insert_drive_file_outlined,
              "Drafts",
              isActive: emailPro.selectedFolder == 'drafts',
              onTap: () => emailPro.setFolder(context, 'drafts'),
            ),
            _buildSidebarItem(
              Icons.outbox_rounded,
              "Outbox",
              isActive: emailPro.selectedFolder == 'outbox',
              onTap: () => emailPro.setFolder(context, 'outbox'),
            ),
            _buildSidebarItem(
              Icons.edit_note_rounded,
              "Compose",
              onTap: () {
                setState(() {
                  isComposing = true;
                });
              },
            ),
            const Divider(thickness: 0.2, color: Colors.grey),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "FOLDERS",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: folderController,
                      decoration: InputDecoration(
                        hintText: "New folder",
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    height: 30,
                    child: ElevatedButton(
                      onPressed: () {
                        if (folderController.text.trim().isNotEmpty) {
                          final newFolder = folderController.text.trim();
                          FocusScope.of(context).unfocus();
                          emailPro.createFolder(context, newFolder);
                          folderController.clear();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: const Text(
                        "Add",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if ((emailPro.emailData?.mailFolders ?? []).isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "No custom folders found.",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              )
            else
              ...(emailPro.emailData?.mailFolders ?? []).map(
                (folder) => _buildCustomFolderItem(
                  folder.name,
                  isActive: emailPro.selectedFolder == folder.name,
                  onTap: () => emailPro.setFolder(
                    context,
                    folder.name,
                    folderId: folder.id,
                  ),
                ),
              ),
            const SizedBox(height: 40),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          "CONNECTED ACCOUNTS",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            emailPro.isAddingAccount = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                size: 14,
                                color: Color(0xFF2563EB),
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Add",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildConnectedAccount(emailPro),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2, left: 4, right: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.amber.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        leading: Icon(
          icon,
          size: 18,
          color: isActive ? AppColors.amber : Colors.black87,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? AppColors.amber : Colors.black87,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildCustomFolderItem(
    String title, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4, left: 12, right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF3FC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: const Icon(
          Icons.folder_outlined,
          size: 18,
          color: Color(0xFF3A73E5),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF3A73E5),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildConnectedAccount(EmailPro emailPro) {
    final accounts = emailPro.emailData?.accounts ?? [];
    if (accounts.isEmpty) return const SizedBox();

    return Column(
      children: accounts.map((account) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(
                account.isCurrent ? Icons.check_circle : Icons.circle_outlined,
                color: account.isCurrent
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFCBD5E1),
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.email,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: account.isCurrent
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: account.isCurrent
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (account.isCurrent) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "Current",
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!account.isCurrent)
                InkWell(
                  onTap: () => emailPro.switchAccount(context, account.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "Switch",
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (account.isCurrent)
                _buildAccountAction(
                  const Icon(
                    Icons.logout_rounded,
                    size: 14,
                    color: Color(0xFFF59E0B),
                  ),
                  const Color(0xFFF59E0B),
                  onTap: () => emailPro.disconnectAccount(context, account.id),
                ),
              const SizedBox(width: 8),
              _buildAccountAction(
                const ImageWidget(
                  image: Paths.delete,
                  height: 14,
                  width: 14,
                  color: Color(0xFFEF4444),
                ),
                const Color(0xFFEF4444),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Delete Account"),
                      content: Text(
                        "Are you sure you want to delete ${account.email}?",
                        style: const TextStyle(fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            emailPro.deleteAccount(context, account.id);
                          },
                          child: const Text(
                            "Delete",
                            style: TextStyle(color: Colors.red),
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
      }).toList(),
    );
  }

  Widget _buildAccountAction(Widget icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: icon,
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, EmailPro emailPro) {
    final currentEmail = emailPro.emailData?.selectedAccountEmail ?? "";
    final isDetailView = emailPro.selectedMessage != null;
    final bool needsConnect =
        emailPro.emailData!.connectRequired || emailPro.isAddingAccount;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isDetailView) ...[
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: Color(0xFF1E293B),
              ),
              onPressed: () => emailPro.clearSelectedMessage(),
            ),
            const SizedBox(width: 8),
          ],
          ImageWidget(image: Paths.email, height: 25),
          const SizedBox(width: 12),
          const Text(
            "Email",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          if (!needsConnect) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "($currentEmail)",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (!needsConnect && !isDetailView) ...[
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 250,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (value) => emailPro.searchMail(context, value),
                    decoration: const InputDecoration(
                      hintText: "Search mail...",
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () =>
                      emailPro.searchMail(context, _searchController.text),
                  child: Container(
                    height: 39,
                    width: 39,
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, EmailPro emailPro) {
    if (emailPro.isMessageLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.amber),
      );
    }

    if (emailPro.selectedMessage != null) {
      return _buildMessageDetail(context, emailPro.selectedMessage!, emailPro);
    }

    final messages = emailPro.emailData?.messages ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                color: AppColors.white,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Text(
                  emailPro.selectedFolder.isNotEmpty
                      ? emailPro.selectedFolder[0].toUpperCase() +
                            emailPro.selectedFolder.substring(1)
                      : "Inbox",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (messages.isNotEmpty)
          _buildMessageListHeader(context, emailPro, messages),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.01),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child:
                  emailPro.isLoading &&
                      (emailPro.emailData?.messages.isEmpty ?? true)
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.amber),
                    )
                  : Stack(
                      children: [
                        messages.isEmpty
                            ? _buildEmptyState(
                                emailPro.selectedFolder,
                                context,
                                emailPro,
                              )
                            : _buildMessagesList(messages, context, emailPro),
                        if (emailPro.isLoading && messages.isNotEmpty)
                          Positioned.fill(
                            child: Container(
                              color: Colors.white.withValues(alpha: 0.5),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.amber,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    String folder,
    BuildContext context,
    EmailPro emailPro,
  ) {
    return RefreshIndicator(
      onRefresh: () => emailPro.fetchMailData(context),
      color: AppColors.amber,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: 400, // Sufficient height to allow scrolling
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mail_outline_rounded,
                size: 56,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                "No messages in your $folder",
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageDetail(
    BuildContext context,
    EmailMessage message,
    EmailPro emailPro,
  ) {
    double webViewHeight = 500; // initial fallback height

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Scrollbar(
              thumbVisibility: true,
              controller: _detailScrollController,
              child: SingleChildScrollView(
                controller: _detailScrollController,
                primary: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Subject, Reply button, Delete button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              message.subject,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F1F1F),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.reply,
                              size: 16,
                              color: Colors.black54,
                            ),
                            label: const Text(
                              "Reply",
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.all(12),
                              minimumSize: const Size(0, 0),
                            ),
                            child: const ImageWidget(
                              image: Paths.delete,
                              height: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sender Info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF4285F4),
                            child: Text(
                              message.from.isNotEmpty
                                  ? message.from[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.from,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "<no-reply@placeholder.com>",
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "To: ${emailPro.emailData?.selectedAccountEmail ?? ''}",
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Divider(color: Colors.grey.shade100, height: 1),

                    // WebView
                    SizedBox(
                      height: webViewHeight,
                      child: InAppWebView(
                        initialData: InAppWebViewInitialData(
                          data: message.body,
                        ),
                        initialSettings: InAppWebViewSettings(
                          transparentBackground: true,
                          javaScriptEnabled: true,
                          disableVerticalScroll: true,
                          disableHorizontalScroll: false,
                          builtInZoomControls: false,
                          displayZoomControls: false,
                          supportZoom: false,
                        ),
                        onWebViewCreated: (controller) {
                          controller.addJavaScriptHandler(
                            handlerName: "UpdateHeight",
                            callback: (args) {
                              if (args.isNotEmpty) {
                                final h = double.tryParse(args[0].toString());
                                if (h != null && h > 0 && h != webViewHeight) {
                                  setState(() {
                                    webViewHeight = h + 20; // Extra padding
                                  });
                                }
                              }
                            },
                          );
                        },
                        onLoadStop: (controller, url) async {
                          await controller.evaluateJavascript(
                            source: """
                          function sendHeight() {
                            var height = Math.max(
                              document.body.scrollHeight, document.documentElement.scrollHeight,
                              document.body.offsetHeight, document.documentElement.offsetHeight,
                              document.body.clientHeight, document.documentElement.clientHeight
                            );
                            window.flutter_inappwebview.callHandler('UpdateHeight', height);
                          }
                          setTimeout(sendHeight, 100);
                          new ResizeObserver(sendHeight).observe(document.body);
                        """,
                          );
                        },
                      ),
                    ),
                    if (message.attachments.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          "ATTACHMENTS",
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: message.attachments.map((att) {
                            return _buildAttachmentCard(context, att);
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessagesList(
    List<EmailMessage> messages,
    BuildContext context,
    EmailPro emailPro,
  ) {
    return RefreshIndicator(
      onRefresh: () => emailPro.fetchMailData(context),
      color: AppColors.amber,
      child: Scrollbar(
        thumbVisibility: true,
        controller: _listScrollController,
        child: ListView.builder(
          controller: _listScrollController,
          physics:
              const AlwaysScrollableScrollPhysics(), // Ensure it's always scrollable for RefreshIndicator
          primary: false,
          padding: EdgeInsets.zero,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return _buildMessageRow(
              message,
              isLast: index == messages.length - 1,
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageListHeader(
    BuildContext context,
    EmailPro emailPro,
    List<EmailMessage> messages,
  ) {
    bool allSelected =
        selectedMessageIds.length == messages.length && messages.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 10, 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: allSelected,
              activeColor: AppColors.amber,
              side: BorderSide(color: Colors.grey.shade300, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    selectedMessageIds.addAll(messages.map((m) => m.id));
                  } else {
                    selectedMessageIds.clear();
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            "All",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            "${selectedMessageIds.length}",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(width: 20),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(8),
                hint: const Text(
                  "Move to...",
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
                value: selectedMoveToFolderId,
                icon: const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
                onChanged: (folderId) {
                  setState(() {
                    selectedMoveToFolderId = folderId;
                  });
                },
                items:
                    emailPro.emailData?.mailFolders.map((folder) {
                      return DropdownMenuItem<int>(
                        value: folder.id,
                        child: Text(
                          folder.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList() ??
                    [],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              if (selectedMoveToFolderId != null &&
                  selectedMessageIds.isNotEmpty) {
                emailPro
                    .moveMessages(
                      context,
                      selectedMoveToFolderId!,
                      selectedMessageIds.toList(),
                    )
                    .then((_) {
                      setState(() {
                        selectedMessageIds.clear();
                        selectedMoveToFolderId = null;
                      });
                    });
              } else if (selectedMessageIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please select messages to move."),
                  ),
                );
              } else if (selectedMoveToFolderId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please select a destination folder."),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow(EmailMessage message, {bool isLast = false}) {
    // Generate initials and random soft background color
    final initials = message.from.isNotEmpty
        ? message.from[0].toUpperCase()
        : "?";
    final colors = [
      const Color(0xFFF3E5F5), // Purple
      const Color(0xFFE3F2FD), // Blue
      const Color(0xFFE8F5E9), // Green
      const Color(0xFFFFF3E0), // Orange
    ];
    final avatarColor = colors[message.from.length % colors.length];
    final textColor = const Color(0xFF673AB7); // Darker tone for purple

    // Date formatting
    String displayDate = message.date;
    if (displayDate.contains('T')) {
      try {
        final dt = DateTime.parse(displayDate);
        final months = [
          "Jan",
          "Feb",
          "Mar",
          "Apr",
          "May",
          "Jun",
          "Jul",
          "Aug",
          "Sep",
          "Oct",
          "Nov",
          "Dec",
        ];
        displayDate = "${months[dt.month - 1]} ${dt.day}";
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade50, width: 1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final emailProvider = context.read<EmailPro>();
            final accountId = emailProvider.emailData?.selectedAccountId ?? 0;
            emailProvider.fetchMessageDetails(context, message.id, accountId);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: selectedMessageIds.contains(message.id),
                    activeColor: AppColors.amber,
                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selectedMessageIds.add(message.id);
                        } else {
                          selectedMessageIds.remove(message.id);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: avatarColor,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Text(
                    message.from,
                    style: TextStyle(
                      fontWeight: message.isUnread
                          ? FontWeight.w800
                          : FontWeight.w500,
                      fontSize: 13,
                      color: const Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 8,
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: message.subject,
                          style: TextStyle(
                            fontWeight: message.isUnread
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: " — ${message.bodySnippet}",
                          style: const TextStyle(
                            color: Color(0xFFB0B0B0),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  displayDate,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: message.isUnread
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPagination(EmailPro emailPro) {
    final emailData = emailPro.emailData;
    if (emailData == null) return const SizedBox.shrink();

    final nextToken = emailData.nextToken;
    final prevToken = emailData.prevToken;
    final totalItems = emailData.totalItems ?? 0;
    final startItem = emailData.startItem ?? 0;
    final endItem = emailData.endItem ?? 0;
    final isSearching = emailPro.lastSearchQuery.isNotEmpty;

    // Calculate current page and total pages (assuming 100 items per page as seen in UI)
    final int itemsPerPage = 100;
    final int currentPage = (startItem > 0)
        ? (startItem / itemsPerPage).ceil()
        : 1;
    final int totalPages = (totalItems > 0)
        ? (totalItems / itemsPerPage).ceil()
        : 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Text(
            "$startItem-$endItem of $totalItems",
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          // First Page
          _buildPaginationCircle(
            Icons.keyboard_double_arrow_left_rounded,
            onTap: currentPage > 1
                ? () {
                    // Note: tokens don't easily support "first page" unless we just call without a token
                    if (isSearching) {
                      emailPro.searchMail(context, emailPro.lastSearchQuery);
                    } else {
                      emailPro.fetchMailData(context);
                    }
                  }
                : null,
            isEnabled: currentPage > 1,
          ),
          // Previous Page
          _buildPaginationCircle(
            Icons.keyboard_arrow_left_rounded,
            onTap: prevToken != null
                ? () {
                    if (isSearching) {
                      emailPro.searchMail(
                        context,
                        emailPro.lastSearchQuery,
                        nextToken: prevToken,
                      );
                    } else {
                      emailPro.fetchMailData(context, nextToken: prevToken);
                    }
                  }
                : null,
            isEnabled: prevToken != null,
          ),

          // Page Numbers (Showing up to 5 as in design)
          ...List.generate(5, (index) {
            final pageNum = index + 1;
            if (pageNum > totalPages && totalPages > 0) {
              return const SizedBox.shrink();
            }

            return _buildPageNumberCircle(
              pageNum.toString(),
              isActive: pageNum == currentPage,
              onTap: pageNum == currentPage + 1 && nextToken != null
                  ? () {
                      if (isSearching) {
                        emailPro.searchMail(
                          context,
                          emailPro.lastSearchQuery,
                          nextToken: nextToken,
                        );
                      } else {
                        emailPro.fetchMailData(context, nextToken: nextToken);
                      }
                    }
                  : pageNum == currentPage - 1 && prevToken != null
                  ? () {
                      if (isSearching) {
                        emailPro.searchMail(
                          context,
                          emailPro.lastSearchQuery,
                          nextToken: prevToken,
                        );
                      } else {
                        emailPro.fetchMailData(context, nextToken: prevToken);
                      }
                    }
                  : null,
            );
          }),

          // Next Page
          _buildPaginationCircle(
            Icons.keyboard_arrow_right_rounded,
            onTap: nextToken != null
                ? () {
                    if (isSearching) {
                      emailPro.searchMail(
                        context,
                        emailPro.lastSearchQuery,
                        nextToken: nextToken,
                      );
                    } else {
                      emailPro.fetchMailData(context, nextToken: nextToken);
                    }
                  }
                : null,
            isEnabled: nextToken != null,
          ),
          // Last Page (Dummy for now as tokens don't support jump to end)
          _buildPaginationCircle(
            Icons.keyboard_double_arrow_right_rounded,
            onTap: null,
            isEnabled: false,
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationCircle(
    IconData icon, {
    VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        height: 32,
        width: 32,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isEnabled ? Colors.grey.shade200 : Colors.grey.shade100,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isEnabled ? Colors.black87 : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildPageNumberCircle(
    String text, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        height: 32,
        width: 32,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.amber : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? AppColors.amber : Colors.grey.shade200,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isActive ? Colors.black : Colors.black87,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionScreen(BuildContext context, EmailPro emailPro) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF5F7F9),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 500,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.mail_outline_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Connect your mailbox",
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text:
                            "Sync your inbox to read, send, and manage emails directly inside ",
                      ),
                      TextSpan(
                        text: "Print Helpers",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      TextSpan(text: ". Powered by "),
                      TextSpan(
                        text: "Aurinko",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.amber,
                        ),
                      ),
                      TextSpan(text: "."),
                    ],
                  ),
                ),
                if (emailPro.connectionError != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFEE2E2)),
                    ),
                    child: Text(
                      emailPro.connectionError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                ...(() {
                  final services =
                      emailPro.emailData?.connectContext?.services ?? [];
                  final displayServices = services.isNotEmpty
                      ? services
                      : [
                          EmailService(
                            service: 'Google',
                            title: 'Google',
                            enabled: true,
                          ),
                          EmailService(
                            service: 'Office365',
                            title: 'Office 365',
                            enabled: true,
                          ),
                          EmailService(
                            service: 'iCloud',
                            title: 'iCloud',
                            enabled: true,
                          ),
                          EmailService(
                            service: 'imap',
                            title: 'IMAP',
                            enabled: true,
                          ),
                        ];

                  return displayServices.map((service) {
                    return _buildServiceTile(
                      title: service.title,
                      service: service.service,
                      onTap: () =>
                          emailPro.connectService(context, service.service),
                    );
                  });
                })(),
                if (emailPro.isAddingAccount) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        emailPro.isAddingAccount = false;
                      });
                    },
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTile({
    required String title,
    required String service,
    required VoidCallback onTap,
  }) {
    // Determine the display title and icon
    String displayTitle = "Connect $title";
    if (title.toLowerCase().contains("google")) {
      displayTitle = "Connect Gmail / Google Workspace";
    } else if (title.toLowerCase().contains("office") ||
        title.toLowerCase().contains("outlook")) {
      displayTitle = "Connect Outlook / Office 365";
    } else if (title.toLowerCase().contains("icloud")) {
      displayTitle = "Connect iCloud Mail";
    } else if (title.toLowerCase().contains("imap")) {
      displayTitle = "Connect via IMAP";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _getServiceIcon(service),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Connect securely",
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getServiceIcon(String serviceType) {
    String? url;
    final type = serviceType.toLowerCase();
    if (type.contains('google') || type.contains('gmail')) {
      url =
          'https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Google_%22G%22_Logo.svg/512px-Google_%22G%22_Logo.svg.png';
    } else if (type.contains('office') || type.contains('outlook')) {
      url =
          'https://upload.wikimedia.org/wikipedia/commons/thumb/d/df/Microsoft_Office_Outlook_%282018%E2%80%93present%29.svg/512px-Microsoft_Office_Outlook_%282018%E2%80%93present%29.svg.png';
    } else if (type.contains('icloud')) {
      url =
          'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1c/ICloud_logo.svg/512px-ICloud_logo.svg.png';
    }

    if (type.contains('imap')) {
      return const Icon(
        Icons.storage_rounded,
        size: 24,
        color: Color(0xFF64748B),
      );
    }
    if (url != null) {
      return Image.network(
        url,
        height: 24,
        width: 24,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.email, size: 24),
      );
    }
    return const Icon(Icons.email, size: 24);
  }

  Widget _buildAttachmentCard(
    BuildContext context,
    Map<String, dynamic> attachment,
  ) {
    final name = attachment['name'] ?? 'Unknown File';
    final mimeType = attachment['mimeType'] ?? '';
    final downloadUrl = attachment['download_url'];
    final isImage = mimeType.toString().startsWith('image/');

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.attach_file_rounded,
                  size: 16,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    if (downloadUrl != null) {
                      launchUrl(Uri.parse(downloadUrl));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      size: 14,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isImage) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            Container(
              height: 150,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Center(
                child: downloadUrl != null
                    ? Image.network(
                        downloadUrl,
                        fit: BoxFit.cover,
                        headers: {
                          'Authorization':
                              'Bearer ${Provider.of<AuthPro>(context, listen: false).token}',
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.image_not_supported_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                      )
                    : const Icon(
                        Icons.image_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmailInputWidget extends StatefulWidget {
  final List<String> emails;
  final ValueChanged<List<String>> onChanged;
  final String hintText;
  final TextEditingController controller;

  const _EmailInputWidget({
    required this.emails,
    required this.onChanged,
    required this.hintText,
    required this.controller,
  });

  @override
  _EmailInputWidgetState createState() => _EmailInputWidgetState();
}

class _EmailInputWidgetState extends State<_EmailInputWidget> {
  void _addEmail() {
    final text = widget.controller.text.trim().replaceAll(',', '');
    if (text.isNotEmpty) {
      widget.onChanged([...widget.emails, text]);
      widget.controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...widget.emails.map(
          (e) => Chip(
            label: Text(e, style: const TextStyle(fontSize: 12)),
            backgroundColor: AppColors.amber.withValues(alpha: 0.2),
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            onDeleted: () {
              final newEmails = List<String>.from(widget.emails)..remove(e);
              widget.onChanged(newEmails);
            },
            deleteIcon: const Icon(Icons.close, size: 14),
          ),
        ),
        IntrinsicWidth(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 100),
            child: TextField(
              controller: widget.controller,
              onSubmitted: (_) => _addEmail(),
              onChanged: (val) {
                if (val.endsWith(',') || val.endsWith(' ')) {
                  _addEmail();
                }
              },
              decoration: InputDecoration(
                hintText: widget.emails.isEmpty ? widget.hintText : "",
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
