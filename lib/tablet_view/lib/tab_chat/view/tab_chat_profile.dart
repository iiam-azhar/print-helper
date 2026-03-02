import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../tab_constants/colors.dart';
import '../../tab_widgets/tab_image_widget.dart';
import '../../tab_widgets/tab_text_widget.dart';

import '../../tab_constants/paths.dart' show Paths;
import '../../tab_widgets/tab_spacers.dart';

class ProfileDetails extends StatefulWidget {
  const ProfileDetails({super.key});

  @override
  State<ProfileDetails> createState() => _ProfileDetailsState();
}

class _ProfileDetailsState extends State<ProfileDetails> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        surfaceTintColor: Colors.white,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(CupertinoIcons.back, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          children: [
            _profileHeader(),
            Spacers.sb15(),
            ExpandableCard(title: "Company", child: _companyBody()),
            Spacers.sb15(),
            ExpandableCard(title: "About", child: _aboutSection()),
            Spacers.sb15(),
            ExpandableCard(
              title: "Recordings",
              child: Padding(padding: EdgeInsets.all(16), child: _recordings()),
            ),
            Spacers.sb15(),
          ],
        ),
      ),
    );
  }

  Widget _profileHeader() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(70),
          child: ImageWidget(
            image:
                "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e",
            height: 140,
            width: 140,
            fit: BoxFit.cover,
          ),
        ),
        Spacers.sb8(),
        TextWidget(
          text: "Haissel Gut",
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        TextWidget(
          text: "Wholesale",
          fontSize: 12,
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ],
    );
  }

  Widget _companyBody() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: Icon(Icons.business, color: Colors.purple),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: "Company Name goes here",
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                Spacers.sb5(),
                TextWidget(
                  text: "Wholesale | 01/24/21 - 12:20pm",
                  fontSize: 11.5,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
                Spacers.sb5(),
                TextWidget(
                  text: "4 Projects - 3 Files",
                  fontSize: 11.5,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
                Spacers.sb5(),
                TextWidget(
                  text: "3 Contact(s)",
                  fontSize: 11.5,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
                Spacers.sb12(),
                SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {},
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: TextWidget(
                        text: "View Page",
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutSection() {
    return Align(
      alignment: AlignmentGeometry.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextWidget(
              text: "Phones:",
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            Spacers.sb5(),
            TextWidget(
              text: "(323) 000-0000",
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            TextWidget(
              text: "(323) 000-12345",
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            TextWidget(
              text: "jeru@email.com",
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            Spacers.sb10(),
            TextWidget(
              text: "Preferred Languages:",
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            Spacers.sb2(),
            TextWidget(
              text: "Spanish",
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            Spacers.sb5(),
          ],
        ),
      ),
    );
  }

  Widget _recordings() {
    return Column(
      children: List.generate(2, (index) {
        return Container(
          margin: EdgeInsets.only(bottom: 10, left: 18, right: 18),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xffF2F2F2),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.play_arrow),
              ),
              Spacers.sbw12(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: "•၊၊||၊|။||||။၊|၊||၊||၊။၊|။•",
                      fontSize: 17,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                    Spacers.sb5(),
                    TextWidget(
                      text: "00:00/00:30",
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.w400,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextWidget(
                        text: "2024/02/05 - 4:56 pm",
                        fontSize: 12,
                        color: Colors.black,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.file_download_outlined, size: 28),
            ],
          ),
        );
      }),
    );
  }
}

class ExpandableCard extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  const ExpandableCard({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
  });

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(color: Colors.white),
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xffF3F3F3),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(14),
                      bottom: _expanded ? Radius.zero : Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      TextWidget(
                        text: widget.title,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      const Spacer(),
                      AnimatedRotation(
                        turns: _expanded ? .5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const ImageWidget(
                          image: Paths.arrowUp,
                          height: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: _expanded ? widget.child : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
