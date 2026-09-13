import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';
import '../domain/assessment.dart';
import 'assessments_grid.dart';
import 'participants_list.dart';
import 'pages_grid.dart';

/// Which of the three drill-down levels (assessments grid ->
/// participants list -> pages grid) is currently shown. Held here in
/// the shell rather than via Navigator push, since the whole flow stays
/// inside one tab and a simple breadcrumb suffices.
sealed class _AssessmentsView {
  const _AssessmentsView();
}

class _AtAssessments extends _AssessmentsView {
  const _AtAssessments();
}

class _AtParticipants extends _AssessmentsView {
  const _AtParticipants(this.assessment);
  final Assessment assessment;
}

class _AtPages extends _AssessmentsView {
  const _AtPages(this.assessment, this.participant);
  final Assessment assessment;
  final Participant participant;
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

  // Locked default per earlier decision — raw scans load first; a
  // toggle to switch variants can be added to the app bar later.
  final ScanVariant _variant = ScanVariant.raw;

  void _openAssessment(Assessment assessment) {
    setState(() => _view = _AtParticipants(assessment));
  }

  void _openParticipant(Assessment assessment, Participant participant) {
    setState(() => _view = _AtPages(assessment, participant));
  }

  void _goToAssessments() {
    setState(() => _view = const _AtAssessments());
  }

  void _goToParticipants(Assessment assessment) {
    setState(() => _view = _AtParticipants(assessment));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
                      onAssessment: _goToParticipants,
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

    if (view is _AtParticipants) {
      return ParticipantsList(
        assessment: view.assessment,
        onOpen: (participant) => _openParticipant(view.assessment, participant),
      );
    }

    if (view is _AtPages) {
      return PagesGrid(
        assessment: view.assessment,
        participant: view.participant,
        variant: _variant,
      );
    }

    return const SizedBox.shrink();
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.view,
    required this.onAssessments,
    required this.onAssessment,
  });

  final _AssessmentsView view;
  final VoidCallback onAssessments;
  final ValueChanged<Assessment> onAssessment;

  @override
  Widget build(BuildContext context) {
    final crumbs = <Widget>[
      _crumb('Assessments', onAssessments, isLast: view is _AtAssessments),
    ];

    final v = view;
    if (v is _AtParticipants) {
      crumbs.add(_separator());
      crumbs.add(_crumb(v.assessment.name, null, isLast: true));
    } else if (v is _AtPages) {
      crumbs.add(_separator());
      crumbs.add(_crumb(v.assessment.name, () => onAssessment(v.assessment)));
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