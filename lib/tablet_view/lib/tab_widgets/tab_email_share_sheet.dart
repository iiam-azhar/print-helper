import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/files_pro.dart';
import 'tab_toasts.dart';
import 'loaders.dart';
import '../../../constants/colors.dart';
import '../tab_constants/paths.dart';
import '../tab_widgets/tab_text_widget.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_email_recipient_picker.dart';

class TabEmailShareSheet {
  static Future<void> show({
    required BuildContext context,
    required List<Map<String, dynamic>> items,
  }) async {
    final pro = Provider.of<FilesPro>(context, listen: false);
    if (pro.emailShareOptions == null) {
      pro.fetchEmailShareOptions();
    }

    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    final manualEmailController = TextEditingController();
    final sentToController = TextEditingController();
    final List<String> recipients = [];

    Map<String, dynamic>? selectedReplyTo;
    String? selectedReplyToEmail;
    List<Map<String, dynamic>> selectedSentToUsers = [];
    List<String> selectedSentToEmails = [];

    String? subjectError;
    String? messageError;
    String? replyEmailError;
    String? recipientError;
    String? sentToEmailError;

    void addRecipient(StateSetter setModalState, String rawValue) {
      final value = rawValue.trim();
      if (value.isEmpty) return;
      final exists = recipients.any(
        (existing) => existing.toLowerCase() == value.toLowerCase(),
      );
      if (exists) return;
      setModalState(() {
        recipients.add(value);
        recipientError = null;
        sentToEmailError = null;
      });
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'EmailSharePanel',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (_, anim, _, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      pageBuilder: (ctx, _, _) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Consumer<FilesPro>(
              builder: (context, pro, child) {
                if (pro.emailOptionsLoading) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 340,
                        height: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            bottomLeft: Radius.circular(30),
                          ),
                        ),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  );
                }

                List<Map<String, dynamic>> availableUsers = [];
                if (pro.emailShareOptions != null) {
                  availableUsers = List<Map<String, dynamic>>.from(
                    pro.emailShareOptions!['users'] ?? [],
                  );

                  if (selectedReplyTo == null) {
                    final defaultIds = List<int>.from(
                      pro.emailShareOptions!['default_reply_to_user_ids'] ?? [],
                    );
                    if (defaultIds.isNotEmpty &&
                        availableUsers.any((e) => e['id'] == defaultIds[0])) {
                      selectedReplyTo = availableUsers.firstWhere(
                        (e) => e['id'] == defaultIds[0],
                      );
                      // Initialize selected email from default
                      final defaultEmail = pro
                          .emailShareOptions!['default_reply_to_email']
                          ?.toString();
                      if (defaultEmail != null && defaultEmail.isNotEmpty) {
                        selectedReplyToEmail = defaultEmail;
                      }
                    } else if (availableUsers.isNotEmpty) {
                      selectedReplyTo = availableUsers.first;
                    }
                  }
                }

                return Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 340,
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          bottomLeft: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, 14, 12, 8),
                            child: Row(
                              children: [
                                ImageWidget(
                                  image: Paths.email,
                                  width: 24,
                                  height: 24,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: TextWidget(
                                    text: 'Email File(s)',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextWidget(
                                    text: 'Subject',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  SizedBox(height: 8),
                                  TextField(
                                    controller: subjectController,
                                    onChanged: (val) {
                                      if (subjectError != null &&
                                          val.trim().isNotEmpty) {
                                        setModalState(
                                          () => subjectError = null,
                                        );
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Type subject',
                                      hintStyle: TextStyle(
                                        color: Colors.black38,
                                        fontSize: 14,
                                      ),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: subjectError != null
                                              ? Colors.red.shade300
                                              : Colors.black12,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: subjectError != null
                                              ? Colors.red.shade300
                                              : Colors.black12,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: subjectError != null
                                              ? Colors.red.shade400
                                              : Colors.black26,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (subjectError != null)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: TextWidget(
                                        text: subjectError!,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                  SizedBox(height: 12),
                                  TextWidget(
                                    text: 'Message',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  SizedBox(height: 8),
                                  TextField(
                                    controller: messageController,
                                    maxLines: 4,
                                    onChanged: (val) {
                                      if (messageError != null &&
                                          val.trim().isNotEmpty) {
                                        setModalState(
                                          () => messageError = null,
                                        );
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Type message',
                                      hintStyle: TextStyle(
                                        color: Colors.black38,
                                        fontSize: 14,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: messageError != null
                                              ? Colors.red.shade300
                                              : Colors.black12,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: messageError != null
                                              ? Colors.red.shade300
                                              : Colors.black12,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: messageError != null
                                              ? Colors.red.shade400
                                              : Colors.black26,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (messageError != null)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: TextWidget(
                                        text: messageError!,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                  SizedBox(height: 12),
                                  TextWidget(
                                    text: 'Select reply to email',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  SizedBox(height: 8),
                                  TabEmailRecipientPicker(
                                    isMultiSelect: false,
                                    hintText: 'Select reply to',
                                    initialSelection: selectedReplyTo != null
                                        ? [selectedReplyTo!]
                                        : [],
                                    users: availableUsers,
                                    onSelectionChanged: (selected) {
                                      setModalState(() {
                                        final newSelected = selected.isNotEmpty
                                            ? selected.first
                                            : null;
                                        if (selectedReplyTo?['id'] !=
                                            newSelected?['id']) {
                                          selectedReplyTo = newSelected;
                                          selectedReplyToEmail = null;
                                          if (selectedReplyTo != null) {
                                            final primary =
                                                selectedReplyTo!['email']
                                                    ?.toString();
                                            if (primary != null &&
                                                primary.isNotEmpty) {
                                              selectedReplyToEmail = primary;
                                            }
                                          }
                                        }
                                        if (selectedReplyTo != null) {
                                          replyEmailError = null;
                                        }
                                      });
                                    },
                                  ),
                                  if (replyEmailError != null)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: TextWidget(
                                        text: replyEmailError!,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                  SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextWidget(
                                        text: 'Reply Email Address',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      if (selectedReplyTo != null &&
                                          selectedReplyToEmail != null)
                                        TextWidget(
                                          text: '1 user selected',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.black38,
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: Builder(
                                      builder: (context) {
                                        final List<String> emails = [];
                                        if (selectedReplyTo != null) {
                                          if (selectedReplyTo!['email'] !=
                                              null) {
                                            emails.add(
                                              selectedReplyTo!['email']
                                                  .toString(),
                                            );
                                          }
                                          if (selectedReplyTo!['emails'] !=
                                              null) {
                                            for (var e
                                                in (selectedReplyTo!['emails']
                                                    as List)) {
                                              if (!emails.contains(
                                                e.toString(),
                                              )) {
                                                emails.add(e.toString());
                                              }
                                            }
                                          }
                                        }

                                        if (selectedReplyTo == null ||
                                            emails.isEmpty) {
                                          return Container(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 40,
                                            ),
                                            alignment: Alignment.center,
                                            child: TextWidget(
                                              text:
                                                  'No emails found for the selected reply user.',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black38,
                                            ),
                                          );
                                        }

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: EdgeInsets.all(12),
                                              child: Row(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          5,
                                                        ),
                                                    child: ImageWidget(
                                                      image:
                                                          (selectedReplyTo!['image'] !=
                                                                  null &&
                                                              selectedReplyTo!['image']
                                                                  .toString()
                                                                  .isNotEmpty)
                                                          ? selectedReplyTo!['image']
                                                                .toString()
                                                          : Paths.user,
                                                      height: 24,
                                                      width: 24,
                                                      fit: BoxFit.cover,
                                                      errorWidget: ImageWidget(
                                                        image: Paths.user,
                                                        height: 24,
                                                        width: 24,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  TextWidget(
                                                    text:
                                                        selectedReplyTo!['name'] ??
                                                        '',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black54,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Divider(height: 1),
                                            ...emails.map((email) {
                                              final isSelected =
                                                  selectedReplyToEmail == email;
                                              return InkWell(
                                                onTap: () {
                                                  setModalState(() {
                                                    if (isSelected) {
                                                      selectedReplyToEmail =
                                                          null;
                                                    } else {
                                                      selectedReplyToEmail =
                                                          email;
                                                    }
                                                  });
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                                  color: isSelected
                                                      ? const Color(0xffe9f3df)
                                                      : Colors.transparent,
                                                  child: Row(
                                                    children: [
                                                      SizedBox(
                                                        height: 20,
                                                        width: 20,
                                                        child: Checkbox(
                                                          value: isSelected,
                                                          activeColor:
                                                              const Color(
                                                                0xff27ae60,
                                                              ),
                                                          materialTapTargetSize:
                                                              MaterialTapTargetSize
                                                                  .shrinkWrap,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                          onChanged: (val) {
                                                            setModalState(() {
                                                              if (val == true) {
                                                                selectedReplyToEmail =
                                                                    email;
                                                              } else {
                                                                selectedReplyToEmail =
                                                                    null;
                                                              }
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                      SizedBox(width: 12),
                                                      Expanded(
                                                        child: TextWidget(
                                                          text: email,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color: isSelected
                                                              ? Colors.black87
                                                              : Colors.black54,
                                                        ),
                                                      ),
                                                      if (isSelected)
                                                        TextWidget(
                                                          text: 'Selected',
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: const Color(
                                                            0xff27ae60,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  TextWidget(
                                    text: 'Select sent to email',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  SizedBox(height: 8),
                                  TabEmailRecipientPicker(
                                    users: availableUsers,
                                    initialSelection: selectedSentToUsers,
                                    onSelectionChanged: (users) {
                                      setModalState(() {
                                        // Update users
                                        selectedSentToUsers = users;

                                        // Remove emails for users that were unselected
                                        final userIds = users
                                            .map((u) => u['id'])
                                            .toSet();
                                        selectedSentToEmails.removeWhere((
                                          email,
                                        ) {
                                          // Find which user this email belongs to
                                          final owner = availableUsers
                                              .firstWhere((u) {
                                                final primary = u['email']
                                                    ?.toString();
                                                final secondary =
                                                    (u['emails'] as List?)
                                                        ?.map(
                                                          (e) => e.toString(),
                                                        )
                                                        .toList();
                                                return primary == email ||
                                                    (secondary?.contains(
                                                          email,
                                                        ) ??
                                                        false);
                                              }, orElse: () => {});
                                          return owner.isEmpty ||
                                              !userIds.contains(owner['id']);
                                        });

                                        // Add primary emails for newly selected users if not already present
                                        for (var user in users) {
                                          final primary = user['email']
                                              ?.toString();
                                          if (primary != null &&
                                              primary.isNotEmpty &&
                                              !selectedSentToEmails.contains(
                                                primary,
                                              )) {
                                            selectedSentToEmails.add(primary);
                                          }
                                        }
                                        if (selectedSentToUsers.isNotEmpty ||
                                            recipients.isNotEmpty) {
                                          recipientError = null;
                                        }
                                        if (selectedSentToEmails.isNotEmpty ||
                                            recipients.isNotEmpty) {
                                          sentToEmailError = null;
                                        }
                                      });
                                    },
                                  ),
                                  if (recipientError != null)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: TextWidget(
                                        text: recipientError!,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                  SizedBox(height: 12),
                                  if (selectedSentToUsers.isNotEmpty) ...[
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.black12,
                                        ),
                                      ),
                                      child: Column(
                                        children: selectedSentToUsers.map((
                                          user,
                                        ) {
                                          final List<String> userEmails = [];
                                          if (user['email'] != null) {
                                            userEmails.add(
                                              user['email'].toString(),
                                            );
                                          }
                                          if (user['emails'] != null) {
                                            for (var e
                                                in (user['emails'] as List)) {
                                              if (!userEmails.contains(
                                                e.toString(),
                                              )) {
                                                userEmails.add(e.toString());
                                              }
                                            }
                                          }

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: EdgeInsets.fromLTRB(
                                                  12,
                                                  12,
                                                  12,
                                                  8,
                                                ),
                                                child: Row(
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            50,
                                                          ),
                                                      child: ImageWidget(
                                                        image:
                                                            (user['image'] !=
                                                                    null &&
                                                                user['image']
                                                                    .toString()
                                                                    .isNotEmpty)
                                                            ? user['image']
                                                                  .toString()
                                                            : Paths.user,
                                                        height: 24,
                                                        width: 24,
                                                        fit: BoxFit.cover,
                                                        errorWidget:
                                                            ImageWidget(
                                                              image: Paths.user,
                                                              height: 24,
                                                              width: 24,
                                                              fit: BoxFit.cover,
                                                            ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 10),
                                                    TextWidget(
                                                      text: user['name'] ?? '',
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: const Color(
                                                        0xff4b5563,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              ...userEmails.map((email) {
                                                final isSelected =
                                                    selectedSentToEmails
                                                        .contains(email);
                                                return InkWell(
                                                  onTap: () {
                                                    setModalState(() {
                                                      if (isSelected) {
                                                        selectedSentToEmails
                                                            .remove(email);
                                                      } else {
                                                        selectedSentToEmails
                                                            .add(email);
                                                        sentToEmailError = null;
                                                      }
                                                    });
                                                  },
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 10,
                                                        ),
                                                    color: isSelected
                                                        ? const Color(
                                                            0xffe9f3df,
                                                          )
                                                        : Colors.transparent,
                                                    child: Row(
                                                      children: [
                                                        SizedBox(
                                                          height: 20,
                                                          width: 20,
                                                          child: Checkbox(
                                                            value: isSelected,
                                                            activeColor:
                                                                const Color(
                                                                  0xff27ae60,
                                                                ),
                                                            materialTapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    4,
                                                                  ),
                                                            ),
                                                            onChanged: (val) {
                                                              setModalState(() {
                                                                if (val ==
                                                                    true) {
                                                                  selectedSentToEmails
                                                                      .add(
                                                                        email,
                                                                      );
                                                                  sentToEmailError =
                                                                      null;
                                                                } else {
                                                                  selectedSentToEmails
                                                                      .remove(
                                                                        email,
                                                                      );
                                                                }
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child: TextWidget(
                                                            text: email,
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            color: isSelected
                                                                ? Colors.black87
                                                                : Colors
                                                                      .black54,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }),
                                              if (selectedSentToUsers.last !=
                                                  user)
                                                const Divider(height: 1),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                  ],
                                  SizedBox(height: 12),
                                  TextWidget(
                                    text: 'Select email',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            12,
                                            10,
                                            12,
                                            0,
                                          ),
                                          child: TextWidget(
                                            text:
                                                'Add recipient email manually.',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.black.withValues(
                                              alpha: 0.55,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            12,
                                            10,
                                            12,
                                            12,
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.black12,
                                              ),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (recipients.isNotEmpty)
                                                  Padding(
                                                    padding: EdgeInsets.only(
                                                      bottom: 8,
                                                    ),
                                                    child: Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: recipients
                                                          .map(
                                                            (
                                                              email,
                                                            ) => Container(
                                                              padding:
                                                                  EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        10,
                                                                    vertical: 6,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    const Color(
                                                                      0xfff5f6f1,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      6,
                                                                    ),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  TextWidget(
                                                                    text: email,
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color: const Color(
                                                                      0xff4b5563,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 6,
                                                                  ),
                                                                  GestureDetector(
                                                                    onTap: () {
                                                                      setModalState(() {
                                                                        recipients.remove(
                                                                          email,
                                                                        );
                                                                      });
                                                                    },
                                                                    child: Icon(
                                                                      Icons
                                                                          .close,
                                                                      size: 14,
                                                                      color: Colors
                                                                          .black54,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          )
                                                          .toList(),
                                                    ),
                                                  ),
                                                TextField(
                                                  controller:
                                                      manualEmailController,
                                                  onSubmitted: (value) {
                                                    addRecipient(
                                                      setModalState,
                                                      value,
                                                    );
                                                    manualEmailController
                                                        .clear();
                                                  },
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        'Type email and press Enter',
                                                    hintStyle: TextStyle(
                                                      color: Colors.black38,
                                                      fontSize: 14,
                                                    ),
                                                    isDense: true,
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                          vertical: 8,
                                                        ),
                                                    border: InputBorder.none,
                                                    enabledBorder:
                                                        InputBorder.none,
                                                    focusedBorder:
                                                        InputBorder.none,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (recipients.isEmpty)
                                          Container(
                                            width: double.infinity,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 14,
                                            ),
                                            decoration: const BoxDecoration(
                                              border: Border(
                                                top: BorderSide(
                                                  color: Colors.black12,
                                                ),
                                              ),
                                            ),
                                            child: TextWidget(
                                              text:
                                                  'No suggested emails. You can add manually above.',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black38,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (sentToEmailError != null)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: TextWidget(
                                        text: sentToEmailError!,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, 10, 16, 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: Size(0, 42),
                                      side: const BorderSide(
                                        color: Colors.black26,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                    ),
                                    child: TextWidget(
                                      text: 'Cancel',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final typed = manualEmailController.text
                                          .trim();
                                      if (typed.isNotEmpty) {
                                        addRecipient(setModalState, typed);
                                        manualEmailController.clear();
                                      }

                                      if (selectedSentToUsers.isEmpty) {
                                        setModalState(() {
                                          recipientError =
                                              'Please select at least one user';
                                        });
                                        return;
                                      }

                                      if (recipients.isEmpty &&
                                          selectedSentToEmails.isEmpty) {
                                        setModalState(() {
                                          sentToEmailError =
                                              'Please select or add at least one email recipient';
                                        });
                                        return;
                                      }

                                      if (selectedReplyToEmail == null) {
                                        setModalState(() {
                                          replyEmailError =
                                              'Please select a reply email';
                                        });
                                        return;
                                      }

                                      final subject = subjectController.text
                                          .trim();
                                      final message = messageController.text
                                          .trim();

                                      if (subject.isEmpty) {
                                        setModalState(() {
                                          subjectError =
                                              'Please enter a subject';
                                        });
                                        return;
                                      }

                                      if (message.isEmpty) {
                                        setModalState(() {
                                          messageError =
                                              'Please enter a message';
                                        });
                                        return;
                                      }

                                      Loaders.show();
                                      final success = await pro
                                          .shareItemsToEmail(
                                            subject: subject,
                                            message: message,
                                            sentToUserIds: selectedSentToUsers
                                                .map((u) => u['id'] as int)
                                                .toList(),
                                            sentToEmails: [
                                              ...selectedSentToEmails,
                                              ...recipients,
                                            ],
                                            replyToUserIds:
                                                selectedReplyTo != null
                                                ? [
                                                    selectedReplyTo!['id']
                                                        as int,
                                                  ]
                                                : [],
                                            replyToEmail: selectedReplyToEmail,
                                            items: items,
                                          );
                                      Loaders.hide();
                                      if (success && ctx.mounted) {
                                        Navigator.pop(ctx);
                                        showToast(
                                          message:
                                              'Email share prepared successfully',
                                        );
                                      } else {
                                        showToast(
                                          message: 'Failed to share via email',
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      minimumSize: Size(0, 42),
                                      backgroundColor: AppColors.btnClr,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                    ),
                                    child: TextWidget(
                                      text: 'Share',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );

    subjectController.dispose();
    messageController.dispose();
    manualEmailController.dispose();
    sentToController.dispose();
  }
}
