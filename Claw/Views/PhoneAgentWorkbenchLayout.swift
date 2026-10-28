import SwiftUI

struct PhoneAgentWorkbenchLayout: View {
    let examples: [String]
    @Binding var reviewFocus: ClawMissionRunReviewFocus?
    @Binding var presentation: ClawWorkspacePresentationState
    @Binding var continuationEditor: ClawContinuationEditorInputState
    @Binding var taskArgumentEditor: ClawTaskArgumentEditorContext?
    @Binding var artifactPreviewSelection: ClawArtifactPreviewSelection?

    var body: some View {
        GeometryReader { proxy in
            let leftWidth = ClawWorkspaceLayout.leadingColumnWidth(for: proxy.size.width)

            HStack(alignment: .top, spacing: 16) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PhoneAgentCommandPanel(examples: examples) { presentation.selectedDetail = $0 }
                        ClawMissionRunPanel(
                            reviewFocus: $reviewFocus, continuationEditor: $continuationEditor,
                            taskArgumentEditor: $taskArgumentEditor
                        )
                    }
                    .padding(.vertical, 16)
                    .padding(.leading, 16)
                }
                .frame(width: leftWidth)

                Divider()
                    .padding(.vertical, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PhoneAgentReviewColumn(
                            reviewFocus: $reviewFocus, presentation: $presentation,
                            taskArgumentEditor: $taskArgumentEditor, artifactPreviewSelection: $artifactPreviewSelection
                        )
                    }
                    .padding(.vertical, 16)
                    .padding(.trailing, 16)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct PhoneAgentDetailSelector: View {
    @Binding var selection: ClawWorkspaceDetailSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 8)], spacing: 8) {
                ForEach(ClawWorkspaceDetailSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        Label(section.title, systemImage: section.icon)
                            .font(.subheadline.bold())
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: CGFloat(ClawWorkspacePresentationContract.minimumHitArea))
                            .padding(.horizontal, 8)
                            .foregroundStyle(selection == section ? Color.red : Color.primary)
                            .background(
                                selection == section ? Color.red.opacity(0.1) : Color.secondary.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(section.title)
                    .accessibilityHint(ClawWorkspacePresentationContract.navigationHint)
                    .accessibilityAddTraits(selection == section ? .isSelected : [])
                    .accessibilityIdentifier("workspace.details.\(section.rawValue)")
                }
            }
            Text("切换详情不会发送或审批任务")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ClawMissionAdvancedReviewView: View {
    let summary: ClawMissionRunSummary
    let focusedReviewKind: String?
    let liveHealth: ClawMissionRunLiveGatewayHealthStrip
    let onFocusReviewKind: (String) -> Void

    var body: some View {
        let policy = summary.macAgentPolicyDiagnosticsBoard(focusedOn: focusedReviewKind)
        VStack(alignment: .leading, spacing: 12) {
            ClawMissionRunControlSnapshotView(
                snapshot: summary.controlSnapshot(focusedOn: focusedReviewKind, liveHealth: liveHealth),
                onFocusReviewKind: onFocusReviewKind
            )
            ClawMissionRunOperatorStripView(
                strip: summary.operatorStrip(focusedOn: focusedReviewKind, liveHealth: liveHealth, policyBoard: policy),
                onFocusReviewKind: onFocusReviewKind
            )
            ClawMissionRunLoopContinuationBriefView(
                summary: summary.loopContinuationSummary(focusedOn: focusedReviewKind),
                onFocusReviewKind: onFocusReviewKind
            )
            ClawMissionMacAgentReadinessBoardView(
                board: summary.macAgentReadinessBoard(focusedOn: focusedReviewKind),
                onFocusReviewKind: onFocusReviewKind
            )
            ClawMissionMacAgentPolicyDiagnosticsBoardView(board: policy, onFocusReviewKind: onFocusReviewKind)
            ClawMissionMacGatewayActionPreflightMatrixView(
                matrix: summary.macGatewayActionPreflightMatrix(focusedOn: focusedReviewKind),
                onFocusReviewKind: onFocusReviewKind
            )
            ClawMissionMacAgentEvidenceCoverageMapView(
                map: summary.macAgentEvidenceCoverageMap(focusedOn: focusedReviewKind),
                onFocusReviewKind: onFocusReviewKind
            )
            ClawMissionMacAgentNextStepDeckView(
                deck: summary.macAgentNextStepDeck(focusedOn: focusedReviewKind),
                onFocusReviewKind: onFocusReviewKind
            )
            ClawMissionMacAgentRunTimelineView(
                timeline: summary.macAgentRunTimeline(focusedOn: focusedReviewKind),
                onFocusReviewKind: onFocusReviewKind
            )
            ClawMissionMacAgentContinuationGateView(
                gate: summary.macAgentContinuationGate(focusedOn: focusedReviewKind),
                onFocusReviewKind: onFocusReviewKind
            )
            ClawMissionMacAgentReviewRadarView(
                radar: summary.macAgentReviewRadar(focusedOn: focusedReviewKind),
                onFocusReviewKind: onFocusReviewKind
            )
            ClawMissionMacAgentHandoffBriefView(
                brief: summary.macAgentHandoffBrief(focusedOn: focusedReviewKind),
                onFocusReviewKind: onFocusReviewKind
            )
            ClawMissionAgentTraceHandoffPackView(
                pack: summary.agentTraceHandoffPack(focusedOn: focusedReviewKind),
                onFocusReviewKind: onFocusReviewKind
            )
            ClawMissionPayloadSafetyLedgerView(
                ledger: summary.payloadSafetyLedger(focusedOn: focusedReviewKind),
                onFocusReviewKind: onFocusReviewKind
            )
            ClawMissionReviewTrailView(
                trail: summary.evidenceTrailSummary(focusedOn: focusedReviewKind),
                onFocusReviewKind: onFocusReviewKind
            )
            ClawMissionReviewReadinessSummaryView(
                summary: summary.reviewReadinessSummary(focusedOn: focusedReviewKind),
                onFocusReviewKind: onFocusReviewKind
            )
        }
        .padding(.top, 8)
    }
}
