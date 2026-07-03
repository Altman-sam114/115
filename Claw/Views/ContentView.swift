import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: ClawStore
    @State private var selectedTab: MainTab = .link
    @State private var showingImporter = false
    @State private var importError: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LinkDashboardView(
                    showingImporter: $showingImporter,
                    importError: $importError
                )
            }
            .tabItem {
                Label("连接", systemImage: "rectangle.connected.to.line.below")
            }
            .tag(MainTab.link)

            NavigationStack {
                ChatWorkspaceView()
            }
            .tabItem {
                Label("聊天", systemImage: "bubble.left.and.text.bubble.right.fill")
            }
            .tag(MainTab.chat)

            NavigationStack {
                PhoneAgentView()
            }
            .tabItem {
                Label("电脑接管", systemImage: "display.and.arrow.down")
            }
            .tag(MainTab.phoneAgent)

            NavigationStack {
                SkillLibraryView()
            }
            .tabItem {
                Label("能力", systemImage: "square.grid.2x2.fill")
            }
            .tag(MainTab.skills)

            NavigationStack {
                RankingView()
            }
            .tabItem {
                Label("榜单", systemImage: "chart.bar.xaxis")
            }
            .tag(MainTab.ranking)
        }
        .tint(.red)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                do {
                    try store.importArtifacts(from: urls)
                    importError = nil
                } catch let error as ArtifactImportError {
                    importError = error.message
                } catch {
                    importError = error.localizedDescription
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
    }
}

enum MainTab: Hashable {
    case link
    case chat
    case phoneAgent
    case skills
    case ranking
}

struct LinkDashboardView: View {
    @EnvironmentObject private var store: ClawStore
    @Binding var showingImporter: Bool
    @Binding var importError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AppHeroView()

                ModelStatusPanel(
                    showingImporter: $showingImporter,
                    importError: $importError
                )

                DocumentStripView()

                AutomationCenterView()
            }
            .padding(16)
        }
        .background(AppSurfaceBackground())
        .navigationTitle("Claw Link")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppHeroView: View {
    @EnvironmentObject private var store: ClawStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                AppIconMark()
                    .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Claw")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                    Text("本地/自托管电脑接管智能体")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(store.installedStatusText)
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.1), in: Capsule())
                        .foregroundStyle(.red)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                StatPill(value: "\(store.skills.count)", label: "电脑能力")
                StatPill(value: "\(store.documents.count)", label: "策略上下文")
                StatPill(value: "0 MB", label: "模型下载")
            }
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        }
    }
}

struct AppIconMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)

            Image(systemName: "display.and.arrow.down")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .heavy))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ModelStatusPanel: View {
    @EnvironmentObject private var store: ClawStore
    @Binding var showingImporter: Bool
    @Binding var importError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "本地模型", icon: "cpu.fill")

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.model.name)
                            .font(.system(size: 18, weight: .bold))
                        Text(store.model.summary)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Text(store.validation.availability.title)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.orange.opacity(0.12), in: Capsule())
                        .foregroundStyle(.orange)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ModelFact(title: "参数", value: store.model.parameterCount)
                    ModelFact(title: "量化", value: store.model.quantization)
                    ModelFact(title: "上下文", value: "\(store.model.contextLength)")
                    ModelFact(title: "内存", value: store.model.memoryFootprint)
                }

                HStack(spacing: 10) {
                    Button {
                        store.scanLocalArtifacts()
                    } label: {
                        Label("扫描本地", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button {
                        showingImporter = true
                    } label: {
                        Label("导入文件", systemImage: "folder.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }

                Button {
                    store.stageManualImportPreview()
                } label: {
                    Label("模拟已放入模型文件", systemImage: "shippingbox.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryActionButtonStyle())

                if let importError {
                    Text(importError)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                }

                Text(store.model.artifactManifest.importInstruction)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .panelCard()
        }
    }
}

struct ModelFact: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DocumentStripView: View {
    @EnvironmentObject private var store: ClawStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "本地上下文", icon: "doc.on.doc.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.documents) { document in
                        DocumentCard(document: document)
                            .frame(width: 235)
                    }
                }
            }
        }
    }
}

struct DocumentCard: View {
    let document: WorkspaceContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(document.type)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.red)
                Spacer()
                RiskDots(level: document.riskLevel)
            }

            Text(document.title)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(2)

            Text(document.summary)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .panelCard()
    }
}

struct RiskDots: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { index in
                Circle()
                    .fill(index <= level ? Color.red : Color.gray.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

struct AutomationCenterView: View {
    @EnvironmentObject private var store: ClawStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Claw 电脑网关", icon: "network")

            VStack(alignment: .leading, spacing: 10) {
                TextField("Gateway URL", text: $store.gatewayURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)

                SecureField("Gateway Token", text: $store.gatewayToken)
                    .textFieldStyle(.roundedBorder)

                Button {
                    store.setGateway(url: store.gatewayURL, token: store.gatewayToken)
                } label: {
                    Label("保存网关配置", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
            .panelCard()

            VStack(spacing: 10) {
                ForEach(store.automationTargets) { target in
                    AutomationTargetRow(target: target)
                }
            }

            Text(store.lastAutomationDraft)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct AutomationTargetRow: View {
    @EnvironmentObject private var store: ClawStore
    let target: AutomationTarget

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: target.channel.icon)
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(.red.opacity(0.1), in: Circle())
                    .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 2) {
                    Text(target.appName)
                        .font(.system(size: 15, weight: .bold))
                    Text(target.channel.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.draftAutomationPayload(for: target)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .frame(width: 36, height: 32)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            Text(target.actionTitle)
                .font(.system(size: 13, weight: .semibold))
            Text(target.limitation)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .panelCard()
    }
}

struct PhoneAgentView: View {
    @EnvironmentObject private var store: ClawStore

    private let examples = [
        "接管我的电脑，打开浏览器搜索竞品信息，整理成表格后发到 Slack",
        "读取微信新消息并自动回复客户",
        "在项目目录运行测试，失败时定位原因并准备补丁"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PhoneAgentCommandPanel(examples: examples)

                ClawMissionRunPanel()

                PhoneAgentPlanPanel()

                ClawMobileBridgePanel()

                ClawGatewaySessionPanel()

                PhoneAgentPermissionMatrix()

                PhoneAgentExecutionPanel()
            }
            .padding(16)
        }
        .background(AppSurfaceBackground())
        .navigationTitle("Claw Agent")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PhoneAgentCommandPanel: View {
    @EnvironmentObject private var store: ClawStore
    let examples: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "display.and.arrow.down")
                    .font(.system(size: 26, weight: .black))
                    .frame(width: 48, height: 48)
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 3) {
                    Text("OpenClaw 式电脑接管")
                        .font(.system(size: 20, weight: .heavy))
                    Text("手机审批，桌面网关执行")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(store.phoneAgentBoundaryText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("输入要让 Claw 接管电脑完成的工作", text: $store.phoneAgentCommand, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    store.generatePhoneAgentPlan()
                } label: {
                    Label("生成计划", systemImage: "list.bullet.rectangle.portrait.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button {
                    store.simulatePhoneAgentExecution()
                } label: {
                    Label("模拟执行", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(examples, id: \.self) { example in
                        Button {
                            store.usePhoneAgentExample(example)
                        } label: {
                            Text(example)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemBackground), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .panelCard()
    }
}

struct ClawMissionRunPanel: View {
    @EnvironmentObject private var store: ClawStore

    var body: some View {
        let summary = store.missionRunSummary
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Mission Run", icon: "flag.checkered")

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: summary.phaseIcon)
                    .font(.title3.bold())
                    .frame(width: 44, height: 44)
                    .background(phaseTint(for: summary).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(phaseTint(for: summary))

                VStack(alignment: .leading, spacing: 5) {
                    Text(summary.command)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text("手机审批，桌面 Gateway 执行")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                PhoneAgentTag(text: summary.phaseTitle, icon: summary.phaseIcon, tint: phaseTint(for: summary))
                PhoneAgentTag(
                    text: summary.requiresUserApproval ? "需手机确认" : "安全路径",
                    icon: summary.requiresUserApproval ? "person.crop.circle.badge.exclamationmark.fill" : "shield.checkered",
                    tint: summary.requiresUserApproval ? .orange : .green
                )
                PhoneAgentTag(text: store.gatewayDispatchMode.title, icon: "switch.2", tint: .blue)
            }

            ClawMissionStageTrack(stages: summary.stageTrack)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("回合 \(summary.progressCurrent)/\(summary.progressTotal)")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(summary.phaseTitle)
                        .font(.footnote.bold())
                        .foregroundStyle(phaseTint(for: summary))
                }
                ProgressView(value: Double(summary.progressCurrent), total: Double(summary.progressTotal))
                    .tint(phaseTint(for: summary))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ClawMissionMetric(value: "\(summary.riskScore)", label: "风险分", icon: "gauge.with.dots.needle.67percent", tint: riskTint(summary.riskScore))
                ClawMissionMetric(value: "\(summary.approvalCount)", label: "审批点", icon: "checkmark.seal.fill", tint: .orange)
                ClawMissionMetric(value: "\(summary.blockedCount)", label: "阻断", icon: "nosign", tint: summary.blockedCount > 0 ? .red : .secondary)
                ClawMissionMetric(value: "\(summary.artifactCount)", label: "Artifact", icon: "paperclip", tint: .purple)
            }

            HStack(spacing: 8) {
                PhoneAgentTag(text: "\(summary.succeededCount) 成功", icon: "checkmark.circle.fill", tint: .green)
                PhoneAgentTag(text: "\(summary.failedCount) 失败", icon: "xmark.circle.fill", tint: summary.failedCount > 0 ? .red : .secondary)
                PhoneAgentTag(text: "\(summary.retryableCount) 可重试", icon: "arrow.clockwise.circle.fill", tint: summary.retryableCount > 0 ? .orange : .secondary)
            }

            if summary.artifactKinds.isEmpty {
                Label("尚无 Gateway artifact；发送后会显示截图、浏览轨迹、文件变更、命令输出或智能体轨迹。", systemImage: "tray")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(summary.artifactKinds.prefix(5)), id: \.self) { kind in
                            PhoneAgentTag(text: kind.title, icon: "paperclip", tint: .purple)
                        }
                    }
                }
            }

            Text(summary.statusLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(summary.primaryActionTitle, systemImage: summary.primaryActionIcon) {
                performPrimaryAction(summary.primaryActionKind)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(summary.isPrimaryActionEnabled == false)
            .opacity(summary.isPrimaryActionEnabled ? 1 : 0.55)
        }
        .panelCard()
    }

    private func phaseTint(for summary: ClawMissionRunSummary) -> Color {
        switch summary.primaryActionKind {
        case .start:
            return summary.phaseTitle == ClawAutonomousLoopPhase.completed.title ? .green : .blue
        case .approveAndContinue, .continueAfterReview:
            return .orange
        case .waitForGateway:
            return .blue
        case .inspectBlocked:
            return .red
        }
    }

    private func riskTint(_ risk: Int) -> Color {
        if risk >= 70 {
            return .red
        }
        if risk >= 40 {
            return .orange
        }
        return .green
    }

    private func performPrimaryAction(_ action: ClawMissionRunPrimaryActionKind) {
        switch action {
        case .start:
            store.startAutonomousComputerTakeover()
        case .approveAndContinue:
            store.approveAndContinueAutonomousLoop()
        case .continueAfterReview:
            store.continueAutonomousLoopAfterReview()
        case .waitForGateway, .inspectBlocked:
            break
        }
    }
}

struct ClawMissionStageTrack: View {
    let stages: [ClawMissionRunStage]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                ClawMissionStageNode(stage: stage)

                if index < stages.count - 1 {
                    Capsule()
                        .fill(stage.isComplete ? Color.green.opacity(0.65) : Color.secondary.opacity(0.2))
                        .frame(height: 3)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stages.map(\.title).joined(separator: "，"))
    }
}

struct ClawMissionStageNode: View {
    let stage: ClawMissionRunStage

    private var tint: Color {
        if stage.isBlocked {
            return .red
        }
        if stage.isActive {
            return .orange
        }
        if stage.isComplete {
            return .green
        }
        return .secondary
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: stage.icon)
                .font(.caption.bold())
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: Circle())
                .foregroundStyle(tint)
            Text(stage.title)
                .font(.caption.bold())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ClawMissionMetric: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.monospacedDigit().bold())
                    .lineLimit(1)
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PhoneAgentPlanPanel: View {
    @EnvironmentObject private var store: ClawStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "执行计划", icon: "checklist")

            HStack(spacing: 10) {
                PhoneAgentSummaryPill(value: "\(store.phoneAgentPlan.executableStepCount)", label: "可执行")
                PhoneAgentSummaryPill(value: "\(store.phoneAgentPlan.confirmationCount)", label: "需确认")
                PhoneAgentSummaryPill(value: "\(store.phoneAgentPlan.blockedCount)", label: "受限")
            }

            Text(store.phoneAgentPlan.summary)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(Array(store.phoneAgentPlan.steps.enumerated()), id: \.element.id) { index, step in
                    PhoneAgentStepRow(index: index + 1, step: step)
                }
            }

            if store.phoneAgentPlan.blockedNotes.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.phoneAgentPlan.blockedNotes, id: \.self) { note in
                        Label(note, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

struct ClawMobileBridgePanel: View {
    @EnvironmentObject private var store: ClawStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Claw 电脑任务", icon: "display.and.arrow.down")

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "network")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .foregroundStyle(.purple)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.clawGatewayProfile.endpoint)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(store.clawMobileStatusText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    PhoneAgentTag(text: store.clawGatewayProfile.securityMode.title, icon: "lock.shield.fill", tint: .purple)
                    PhoneAgentTag(text: store.clawGatewayProfile.tokenFingerprint, icon: "key.fill", tint: .purple)
                    PhoneAgentTag(text: store.gatewayConnectionText, icon: "dot.radiowaves.left.and.right", tint: .blue)
                }

                Picker("发送模式", selection: $store.gatewayDispatchMode) {
                    ForEach(ClawGatewayDispatchMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    Button {
                        store.queueClawMobileTaskFromCurrentPlan()
                    } label: {
                        Label("生成任务", systemImage: "tray.and.arrow.down.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button {
                        store.approveLatestClawMobileTask()
                    } label: {
                        Label("审批", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button {
                        store.sendLatestClawMobileTask()
                    } label: {
                        Label("发送", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
            .panelCard()

            if store.clawMobileTasks.isEmpty {
                Text("当前没有 Claw 电脑任务。")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(store.clawMobileTasks.prefix(3)) { task in
                        ClawMobileTaskRow(task: task)
                    }
                }
            }

            Text(store.lastClawMobileEnvelope)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct ClawGatewaySessionPanel: View {
    @EnvironmentObject private var store: ClawStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Gateway 会话", icon: "waveform.path.ecg.rectangle.fill")

            HStack(spacing: 8) {
                PhoneAgentTag(text: store.gatewayDispatchMode.title, icon: "switch.2", tint: .blue)
                PhoneAgentTag(text: store.gatewayConnectionState.title, icon: "antenna.radiowaves.left.and.right", tint: .purple)
            }

            Text(store.lastGatewayEvent)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            if let request = store.lastGatewayLiveRequest {
                ClawGatewayLiveRequestCard(request: request)
            }

            if let session = store.clawGatewaySessions.first {
                ClawGatewaySessionCard(session: session)

                if session.retryableCount > 0 {
                    Button {
                        store.retryLatestGatewayFailures()
                    } label: {
                        Label("重试失败动作", systemImage: "arrow.clockwise.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                if store.gatewayEvents.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("事件时间线")
                            .font(.system(size: 13, weight: .heavy))
                        ForEach(Array(store.gatewayEvents.suffix(6).reversed())) { event in
                            ClawGatewayEventRow(event: event)
                        }
                    }
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            } else {
                Text("发送任务后会在这里显示网关事件、截图/日志引用、文件变更和重试状态。")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

struct ClawGatewayLiveRequestCard: View {
    let request: ClawGatewayLiveRequest

    private var tint: Color {
        request.canAttemptLive ? .green : .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: request.canAttemptLive ? "bolt.horizontal.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.12), in: Circle())
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.endpoint.isEmpty ? "未配置 Gateway" : request.endpoint)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(request.preflightMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                PhoneAgentTag(text: request.transport, icon: "point.3.connected.trianglepath.dotted", tint: tint)
                PhoneAgentTag(text: "\(request.actionCount) 动作", icon: "square.stack.3d.forward.dottedline", tint: tint)
                PhoneAgentTag(text: "\(request.bodyBytes) bytes", icon: "doc.plaintext.fill", tint: tint)
            }
        }
        .panelCard()
    }
}

struct ClawGatewaySessionCard: View {
    let session: ClawGatewaySession

    private var tint: Color {
        switch session.status {
        case .prepared:
            return .blue
        case .running:
            return .purple
        case .completed:
            return .green
        case .needsAttention:
            return .orange
        case .blocked:
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "server.rack")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.12), in: Circle())
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.command)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(2)
                    Text(session.channel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                PhoneAgentTag(text: session.status.title, icon: "dot.radiowaves.left.and.right", tint: tint)
                PhoneAgentTag(text: "\(session.succeededCount) 成功", icon: "checkmark.circle.fill", tint: .green)
                PhoneAgentTag(text: "\(session.artifactCount) 证据", icon: "paperclip", tint: .purple)
            }

            VStack(spacing: 8) {
                ForEach(session.results.prefix(4)) { result in
                    ClawGatewayResultRow(result: result)
                }
            }

            if let audit = session.auditTrail.last {
                Text(audit)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .panelCard()
    }
}

struct ClawGatewayEventRow: View {
    let event: ClawGatewayEvent

    private var tint: Color {
        switch event.kind {
        case .sessionPrepared, .liveRequestPrepared, .gatewayConnected, .actionStarted:
            return .blue
        case .artifactStored:
            return .purple
        case .actionCompleted, .sessionCompleted:
            return .green
        case .actionFailed:
            return .red
        case .approvalRequested:
            return .orange
        case .actionSkipped, .fallbackUsed:
            return .gray
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("#\(event.sequence)")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(tint)
                .frame(width: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.kind.title)
                        .font(.system(size: 12, weight: .bold))
                    if let actionTitle = event.actionTitle {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                Text(event.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if event.artifacts.isEmpty == false {
                    HStack(spacing: 6) {
                        ForEach(event.artifacts.prefix(3)) { artifact in
                            PhoneAgentTag(text: artifact.kind.title, icon: "paperclip", tint: tint)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ClawGatewayResultRow: View {
    let result: ClawGatewayActionResult

    private var tint: Color {
        switch result.status {
        case .pending, .running:
            return .blue
        case .succeeded:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .orange
        case .waitingForApproval:
            return .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: result.actionKind.icon)
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(0.1), in: Circle())
                    .foregroundStyle(tint)

                Text(result.actionTitle)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)

                Spacer()

                Text(result.status.title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(tint)
            }

            Text(result.summary)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if result.artifacts.isEmpty == false {
                HStack(spacing: 6) {
                    ForEach(result.artifacts.prefix(3)) { artifact in
                        PhoneAgentTag(
                            text: artifact.kind.title,
                            icon: artifact.isRedacted ? "eye.slash.fill" : "paperclip",
                            tint: artifact.isRedacted ? .orange : .purple
                        )
                    }
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ClawMobileTaskRow: View {
    let task: ClawMobileTask

    private var tint: Color {
        switch task.status {
        case .queued:
            return .red
        case .waitingForApproval:
            return .blue
        case .readyToSend:
            return .green
        case .sent:
            return .purple
        case .blocked:
            return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.12), in: Circle())
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.command)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(2)
                    Text(task.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                PhoneAgentTag(text: task.status.title, icon: "circle.hexagongrid.fill", tint: tint)
                PhoneAgentTag(text: "风险 \(task.riskScore)", icon: "gauge.with.dots.needle.67percent", tint: tint)
                PhoneAgentTag(text: "\(task.actions.count) 动作", icon: "square.stack.3d.forward.dottedline", tint: tint)
            }

            if let firstAction = task.actions.first {
                Text("\(firstAction.kind.title)：\(firstAction.instruction)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .panelCard()
    }
}

struct PhoneAgentSummaryPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        }
    }
}

struct PhoneAgentStepRow: View {
    let index: Int
    let step: PhoneAgentStep

    private var tint: Color {
        if step.isAllowedOnIOS == false {
            return .orange
        }
        return step.requiresUserConfirmation ? .blue : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(index)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.system(size: 15, weight: .bold))
                    Text(step.instruction)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                PhoneAgentTag(text: step.surface.title, icon: step.surface.icon, tint: tint)
                PhoneAgentTag(text: step.runMode.title, icon: step.isAllowedOnIOS ? "checkmark.circle.fill" : "lock.slash.fill", tint: tint)
            }

            Text(step.rationale)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .panelCard()
    }
}

struct PhoneAgentTag: View {
    let text: String
    let icon: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(tint.opacity(0.1), in: Capsule())
            .foregroundStyle(tint)
    }
}

struct PhoneAgentPermissionMatrix: View {
    @EnvironmentObject private var store: ClawStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "权限矩阵", icon: "lock.rectangle.stack.fill")

            VStack(spacing: 10) {
                ForEach(store.phoneAgentCapabilities) { capability in
                    PhoneAgentCapabilityRow(capability: capability)
                }
            }
        }
    }
}

struct PhoneAgentCapabilityRow: View {
    let capability: PhoneAgentCapability

    private var tint: Color {
        switch capability.runMode {
        case .automaticInsideApp, .automaticWithPermission, .shortcutOrSiri:
            return .red
        case .needsUserConfirmation:
            return .blue
        case .gatewayOnly:
            return .purple
        case .blockedByIOS:
            return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: capability.surface.icon)
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.1), in: Circle())
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 3) {
                    Text(capability.title)
                        .font(.system(size: 15, weight: .bold))
                    Text(capability.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                PhoneAgentTag(text: capability.permissionState.title, icon: "person.badge.key.fill", tint: tint)
                PhoneAgentTag(text: capability.runMode.title, icon: "gearshape.2.fill", tint: tint)
            }

            HStack(spacing: 8) {
                CapabilityAccessPill(isEnabled: capability.canRead, label: "读")
                CapabilityAccessPill(isEnabled: capability.canWrite, label: "写")
                Text(capability.framework)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(capability.limitation)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .panelCard()
    }
}

struct CapabilityAccessPill: View {
    let isEnabled: Bool
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .heavy))
            .frame(width: 28, height: 22)
            .background(isEnabled ? Color.red.opacity(0.12) : Color.gray.opacity(0.12), in: Capsule())
            .foregroundStyle(isEnabled ? .red : .secondary)
    }
}

struct PhoneAgentExecutionPanel: View {
    @EnvironmentObject private var store: ClawStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "执行日志", icon: "terminal.fill")

            Text(store.phoneAgentExecutionLog)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct ChatWorkspaceView: View {
    @EnvironmentObject private var store: ClawStore

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    RuntimeBanner()

                    ForEach(store.messages) { message in
                        ChatBubble(message: message)
                    }
                }
                .padding(16)
            }
            .background(AppSurfaceBackground())

            VStack(spacing: 10) {
                SelectedSkillBar()

                HStack(alignment: .bottom, spacing: 10) {
                    TextField("描述要让 Claw 完成的电脑任务", text: $store.query, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(11)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button {
                        store.submitCurrentQuery()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32, weight: .bold))
                    }
                    .disabled(store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(14)
            .background(.white)
        }
        .navigationTitle("Claw Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RuntimeBanner: View {
    @EnvironmentObject private var store: ClawStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.laptopcomputer")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 3) {
                Text("端侧优先 · \(store.validation.availability.title)")
                    .font(.system(size: 14, weight: .bold))
                Text("不会下载模型权重；未校验前只使用模拟 runtime。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .panelCard()
    }
}

struct SelectedSkillBar: View {
    @EnvironmentObject private var store: ClawStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.rankedSkills.prefix(4)) { skill in
                    Button {
                        store.selectSkill(skill)
                    } label: {
                        Label(skill.title, systemImage: skill.icon)
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                store.selectedSkill?.id == skill.id ? Color.red.opacity(0.12) : Color(.secondarySystemBackground),
                                in: Capsule()
                            )
                            .foregroundStyle(store.selectedSkill?.id == skill.id ? .red : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .top) {
            if isUser {
                Spacer(minLength: 42)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let skillTitle = message.skillTitle {
                    Text(skillTitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isUser ? .white.opacity(0.75) : .red)
                }
                Text(message.text)
                    .font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(isUser ? Color.red : Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(isUser ? .white : .primary)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.black.opacity(isUser ? 0 : 0.06), lineWidth: 1)
            }

            if isUser == false {
                Spacer(minLength: 42)
            }
        }
    }
}

struct SkillLibraryView: View {
    @EnvironmentObject private var store: ClawStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "能力分类", icon: "square.grid.3x3.fill")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    CategoryButton(category: nil)
                    ForEach(ClawCapabilityCategory.allCases) { category in
                        CategoryButton(category: category)
                    }
                }

                SectionHeader(title: "热门能力", icon: "star.fill")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(store.visibleSkills) { skill in
                        SkillCard(skill: skill)
                    }
                }
            }
            .padding(16)
        }
        .background(AppSurfaceBackground())
        .navigationTitle("Claw Skills")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CategoryButton: View {
    @EnvironmentObject private var store: ClawStore
    let category: ClawCapabilityCategory?

    private var isSelected: Bool {
        store.selectedCategory == category
    }

    var body: some View {
        Button {
            store.selectedCategory = category
        } label: {
            HStack(spacing: 10) {
                Image(systemName: category?.icon ?? "tray.full.fill")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(isSelected ? Color.red : Color(.secondarySystemBackground), in: Circle())
                    .foregroundStyle(isSelected ? .white : .red)

                Text(category?.title ?? "全部分类")
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.red.opacity(0.5) : Color.black.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SkillCard: View {
    @EnvironmentObject private var store: ClawStore
    let skill: ClawSkill

    var body: some View {
        Button {
            store.selectSkill(skill)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: skill.icon)
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .foregroundStyle(.red)
                    Spacer()
                    Text("\(skill.popularity)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.secondary)
                }

                Text(skill.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(skill.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Label("\(formattedCount(skill.runCount)) 次", systemImage: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelCard()
        }
        .buttonStyle(.plain)
    }

    private func formattedCount(_ count: Int) -> String {
        count >= 10000 ? String(format: "%.1fw", Double(count) / 10000) : "\(count)"
    }
}

struct RankingView: View {
    @EnvironmentObject private var store: ClawStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "能力榜单", icon: "chart.bar.fill")

                ForEach(Array(store.rankedSkills.enumerated()), id: \.element.id) { index, skill in
                    RankingRow(rank: index + 1, skill: skill)
                }
            }
            .padding(16)
        }
        .background(AppSurfaceBackground())
        .navigationTitle("Claw Rank")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RankingRow: View {
    @EnvironmentObject private var store: ClawStore
    let rank: Int
    let skill: ClawSkill

    var body: some View {
        Button {
            store.selectSkill(skill)
        } label: {
            HStack(spacing: 12) {
                Text("\(rank)")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(rank <= 3 ? .white : .secondary)
                    .frame(width: 34, height: 34)
                    .background(rank <= 3 ? Color.red : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Image(systemName: skill.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.red)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(skill.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(skill.category.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(skill.popularity)")
                        .font(.system(size: 14, weight: .heavy))
                    Text("热度")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .panelCard()
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.red)
            Text(title)
                .font(.system(size: 17, weight: .heavy))
            Spacer()
        }
    }
}

struct AppSurfaceBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.975, blue: 0.985),
                Color(red: 0.995, green: 0.965, blue: 0.955)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .background(configuration.isPressed ? Color.red.opacity(0.75) : Color.red, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(.white)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .background(configuration.isPressed ? Color(.tertiarySystemBackground) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(.primary)
    }
}

private extension View {
    func panelCard() -> some View {
        self
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.black.opacity(0.06), lineWidth: 1)
            }
    }
}
