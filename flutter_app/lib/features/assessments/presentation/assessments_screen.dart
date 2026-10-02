import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';
import '../domain/assessment.dart';
import 'activity_info_screen.dart';
import 'assessments_grid.dart';
import 'job_progress_popup.dart';
import 'participants_list.dart';
import 'pages_grid.dart';

/// Which of the four drill-down levels (assessments grid -> activity
/// info -> participants list -> pages grid) is currently shown. Held
/// here in the shell rather than via Navigator push, since the whole
/// flow stays inside one tab and a simple breadcrumb suffices.
sealed class _AssessmentsView {
  const _AssessmentsView();
}

class _AtAssessments extends _AssessmentsView {
  const _AtAssessments();
}

class _AtActivityInfo extends _AssessmentsView {
  const _AtActivityInfo(this.assessment);
  final Assessment assessment;
}

class _AtParticipants extends _AssessmentsView {
  const _AtParticipants(this.assessment, this.variant);
  final Assessment assessment;
  final ScanVariant variant;
}

class _AtPages extends _AssessmentsView {
  const _AtPages(this.assessment, this.participant, this.variant);
  final Assessment assessment;
  final Participant participant;
  final ScanVariant variant;
}

enum AssessmentFilter { all, exams, activities }

class AssessmentsScreen extends StatefulWidget {
  const AssessmentsScreen({super.key});

  @override
  State<AssessmentsScreen> createState() => _AssessmentsScreenState();
}

class _AssessmentsScreenState extends State<AssessmentsScreen> {
  _AssessmentsView _view = const _AtAssessments();
  AssessmentFilter _filter = AssessmentFilter.all;

  void _openAssessment(Assessment assessment) {
    setState(() => _view = _AtActivityInfo(assessment));
  }

  void _openVariant(Assessment assessment, ScanVariant variant) {
    setState(() => _view = _AtParticipants(assessment, variant));
  }

  void _openParticipant(
    Assessment assessment,
    Participant participant,
    ScanVariant variant,
  ) {
    setState(() => _view = _AtPages(assessment, participant, variant));
  }

  void _goToAssessments() {
    setState(() => _view = const _AtAssessments());
  }

  void _goToActivityInfo(Assessment assessment) {
    setState(() => _view = _AtActivityInfo(assessment));
  }

  void _goToParticipants(Assessment assessment, ScanVariant variant) {
    setState(() => _view = _AtParticipants(assessment, variant));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Stack so the import / clean / crop progress popup can float
      // bottom-right above whichever drill-down level is showing. It
      // reads Firestore state itself, so it keeps updating while you
      // navigate between levels and disappears when no job is running.
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const ProvaHeaderBanner(
                  pageTitle: 'Assessments',
                  stage: PipelineStage.notApplicable,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Breadcrumb(
                          view: _view,
                          onAssessments: _goToAssessments,
                          onActivityInfo: _goToActivityInfo,
                          onParticipants: _goToParticipants,
                        ),
                        const SizedBox(height: 16),
                        Expanded(child: _buildBody()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const JobProgressPopup(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final view = _view;

    if (view is _AtAssessments) {
      return AssessmentsGrid(
        filter: _filter,
        onFilterChanged: (f) => setState(() => _filter = f),
        onOpen: _openAssessment,
      );
    }

    if (view is _AtActivityInfo) {
      return ActivityInfoScreen(
        assessment: view.assessment,
        onOpenVariant: (variant) => _openVariant(view.assessment, variant),
      );
    }

    if (view is _AtParticipants) {
      return ParticipantsList(
        assessment: view.assessment,
        onOpen: (participant) =>
            _openParticipant(view.assessment, participant, view.variant),
      );
    }

    if (view is _AtPages) {
      return PagesGrid(
        assessment: view.assessment,
        participant: view.participant,
        variant: view.variant,
      );
    }

    return const SizedBox.shrink();
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.view,
    required this.onAssessments,
    required this.onActivityInfo,
    required this.onParticipants,
  });

  final _AssessmentsView view;
  final VoidCallback onAssessments;
  final ValueChanged<Assessment> onActivityInfo;
  final void Function(Assessment, ScanVariant) onParticipants;

  @override
  Widget build(BuildContext context) {
    final crumbs = <Widget>[
      _crumb('Assessments', onAssessments, isLast: view is _AtAssessments),
    ];

    final v = view;
    if (v is _AtActivityInfo) {
      crumbs.add(_separator());
      crumbs.add(_crumb(v.assessment.name, null, isLast: true));
    } else if (v is _AtParticipants) {
      crumbs.add(_separator());
      crumbs.add(_crumb(
        v.assessment.name,
        () => onActivityInfo(v.assessment),
      ));
      crumbs.add(_separator());
      crumbs.add(_crumb(v.variant.label, null, isLast: true));
    } else if (v is _AtPages) {
      crumbs.add(_separator());
      crumbs.add(_crumb(
        v.assessment.name,
        () => onActivityInfo(v.assessment),
      ));
      crumbs.add(_separator());
      crumbs.add(_crumb(
        v.variant.label,
        () => onParticipants(v.assessment, v.variant),
      ));
      crumbs.add(_separator());
      crumbs.add(_crumb(v.participant.code, null, isLast: true));
    }

    return Row(
      children: [
        ...crumbs,
        if (view is _AtAssessments) ...[
          const Spacer(),
          const Text(
            'Folders are anonymized codes only — no student names anywhere.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  Widget _separator() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text('/', style: TextStyle(color: Colors.grey)),
      );

  Widget _crumb(String label, VoidCallback? onTap, {bool isLast = false}) {
    final style = TextStyle(
      fontSize: 14,
      fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
      color: isLast ? Colors.black : Colors.grey.shade600,
    );

    if (onTap == null) return Text(label, style: style);
    return InkWell(onTap: onTap, child: Text(label, style: style));
  }
}