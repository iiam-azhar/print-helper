import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:print_helper/providers/project_pro.dart';
import '../../tab_services/helpers.dart';
import '../../tab_widgets/tab_image_widget.dart';
import 'package:provider/provider.dart';

import 'package:print_helper/models/projects_models.dart';
import '../../tab_widgets/tab_text_widget.dart';
import '../../tab_widgets/tab_spacers.dart';
import '../../tab_constants/colors.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projPro = getProjPro(context);
      projPro.getProjects(ctx: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(),
      body: SafeArea(
        child: Consumer<ProjectPro>(
          builder: (context, pro, child) {
            if (pro.projectLoad) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = pro.projects;
            return ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: list.length,
              itemBuilder: (context, i) => _projectCard(list[i]),
            );
          },
        ),
      ),
    );
  }

  AppBar _appBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      title: Row(
        children: [
          Icon(CupertinoIcons.doc_text, size: 25),
          Spacers.sbw12(),
          TextWidget(
            text: "Projects",
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ],
      ),
      actions: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary),
          ),
          child: TextWidget(
            text: "+ Project",
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Spacers.sbw8(),
        Icon(Icons.filter_alt_outlined, size: 25),
        Spacers.sbw10(),
      ],
    );
  }

  Widget _projectCard(ProjectModel project) {
    return Container(
      margin: EdgeInsets.only(bottom: 18),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(4, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: .start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    TextWidget(
                      text: project.name,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.black,
                    ),
                    TextWidget(
                      text:
                          "${project.comments} Comments - ${project.files} Files",
                      fontSize: 12,
                      color: AppColors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextWidget(
                      text: project.id,
                      fontSize: 12,
                      color: AppColors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                    TextWidget(
                      text: project.date,
                      fontSize: 11,
                      color: AppColors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(color: Colors.grey.shade300),
          Spacers.sb10(),
          Row(
            children: [
              Icon(CupertinoIcons.person_2, size: 24),
              Spacers.sbw8(),
              TextWidget(
                text: project.company,
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.black,
              ),
            ],
          ),
          if (project.progress > 0) ...[
            Spacers.sb12(),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: project.progress / 100,
                minHeight: 6,
                color: AppColors.green,
                backgroundColor: Colors.grey.shade300,
              ),
            ),
            Spacers.sb5(),
            TextWidget(
              text: "Progress | ${project.progress}%",
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ],
          Spacers.sb12(),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 26, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextWidget(
                  text: project.status,
                  color: AppColors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              Spacer(),
              stackedAvatars(images: project.avatars),
            ],
          ),
        ],
      ),
    );
  }

  Widget stackedAvatars({
    required List<String> images,
    double size = 38,
    int maxToShow = 3,
    double overlap = 0.55,
  }) {
    final show = images.length > maxToShow ? maxToShow : images.length;
    final extra = images.length - show;
    final step = size * overlap;
    return SizedBox(
      width: size + step * (show - 1) + (extra > 0 ? 28 : 0),
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < show; i++)
            Positioned(
              left: i * step,
              child: _avatarWithBorder(images[i], size),
            ),
          if (extra > 0)
            Positioned(
              left: show * step,
              child: _extraCountBubble(extra, size * 0.7),
            ),
        ],
      ),
    );
  }

  Widget _avatarWithBorder(String img, double size) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(1.5),
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: ClipOval(
        child: ImageWidget(
          image: img,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _extraCountBubble(int extra, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: size * 0.08),
      ),
      child: Text(
        '+$extra',
        style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w600),
      ),
    );
  }
}
