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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let examples = [
        "接管我的电脑，打开浏览器搜索竞品信息，整理成表格后发到 Slack",
        "读取微信新消息并自动回复客户",
        "在项目目录运行测试，失败时定位原因并准备补丁"
    ]

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                PhoneAgentWorkbenchLayout(examples: examples)
            } else {
                PhoneAgentCompactLayout(examples: examples)
            }
        }
        .background(AppSurfaceBackground())
        .navigationTitle("Claw Agent")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PhoneAgentCompactLayout: View {
    let examples: [String]

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
    }
}

struct PhoneAgentWorkbenchLayout: View {
    let examples: [String]

    var body: some View {
        GeometryReader { proxy in
            let leftWidth = min(max(proxy.size.width * 0.36, 330), 440)

            HStack(alignment: .top, spacing: 16) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PhoneAgentCommandPanel(examples: examples)
                        ClawMissionRunPanel()
                    }
                    .padding(.vertical, 16)
                    .padding(.leading, 16)
                }
                .frame(width: leftWidth)

                Divider()
                    .padding(.vertical, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PhoneAgentReviewColumn()
                    }
                    .padding(.vertical, 16)
                    .padding(.trailing, 16)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct PhoneAgentReviewColumn: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PhoneAgentReviewSection(title: "计划复核", icon: "checklist") {
                PhoneAgentPlanPanel()
            }
            PhoneAgentReviewSection(title: "Gateway 任务", icon: "display.and.arrow.down") {
                ClawMobileBridgePanel()
            }
            PhoneAgentReviewSection(title: "会话与事件", icon: "waveform.path.ecg.rectangle.fill") {
                ClawGatewaySessionPanel()
            }
            PhoneAgentReviewSection(title: "权限与日志", icon: "lock.rectangle.stack.fill") {
                PhoneAgentPermissionMatrix()
                PhoneAgentExecutionPanel()
            }
        }
    }
}

struct PhoneAgentReviewSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, icon: icon)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

            if let review = summary.artifactMetadataReview {
                ClawGatewayArtifactMetadataReviewRow(review: review)
            }

            if let review = summary.gatewayExtractionCompletenessReview {
                ClawGatewayExtractionCompletenessReviewRow(review: review)
            }

            if let review = summary.gatewayBrowserControlReview {
                ClawGatewayBrowserControlReviewRow(review: review)
            }

            if let review = summary.gatewayDeliverySafetyReview {
                ClawGatewayDeliverySafetyReviewRow(review: review)
            }

            if let review = summary.gatewayCapabilityReview {
                ClawGatewayCapabilityReviewRow(review: review)
            }

            if let review = summary.gatewayAccessibilityReview {
                ClawGatewayAccessibilityReviewRow(review: review)
            }

            if let review = summary.gatewayTaskReplayGuardReview {
                ClawGatewayTaskReplayGuardReviewRow(review: review)
            }

            if let review = summary.agentTraceReview {
                ClawAgentTraceReviewRow(review: review)
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

            ClawGatewayLiveHealthRow(summary: store.gatewayLiveHealthSummary)

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
                    Text(request.safeEndpointDisplay)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(request.preflightMessage)
                        .font(.footnote)
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

struct ClawGatewayLiveHealthRow: View {
    let summary: ClawGatewayLiveHealthSummary

    private var tint: Color {
        if summary.hasError {
            return .red
        }
        if summary.hasFallback {
            return .orange
        }
        if summary.isCompleted {
            return .green
        }
        if summary.connectionState == .streaming {
            return .purple
        }
        return summary.canAttemptLive ? .blue : .secondary
    }

    private var chips: [(text: String, icon: String, tint: Color)] {
        var items: [(String, String, Color)] = [
            (summary.connectionState.title, "antenna.radiowaves.left.and.right", tint),
            (summary.canAttemptLive ? "可 live" : "预览", summary.canAttemptLive ? "bolt.fill" : "eye.fill", summary.canAttemptLive ? .green : .orange),
            (summary.transport, "point.3.connected.trianglepath.dotted", .blue),
            ("\(summary.eventCount) 事件", "number", .purple)
        ]
        if let status = summary.sessionStatus {
            items.append((status.title, "server.rack", tint))
        }
        if let sequence = summary.latestEventSequence,
           let kind = summary.latestEventKind {
            items.append(("#\(sequence) \(kind.title)", "dot.radiowaves.left.and.right", .purple))
        }
        if let fingerprint = summary.tokenFingerprint {
            items.append((fingerprint, "fingerprint", .secondary))
        }
        if summary.transportAttemptCount > 0 {
            items.append(("\(summary.transportAttemptCount) 次尝试", "arrow.triangle.2.circlepath", .blue))
        }
        if summary.hasReconnectAttempt {
            items.append(("重连 \(summary.reconnectCount)", "arrow.clockwise.circle.fill", .orange))
        }
        if let lastPingSucceeded = summary.lastPingSucceeded {
            items.append((lastPingSucceeded ? "ping 正常" : "ping 失败", lastPingSucceeded ? "waveform.circle.fill" : "waveform.path.ecg", lastPingSucceeded ? .green : .orange))
        }
        if let lastTransportErrorSummary = summary.lastTransportErrorSummary {
            items.append((lastTransportErrorSummary, "exclamationmark.octagon.fill", summary.hasError ? .red : .orange))
        }
        if summary.hasFallback {
            items.append(("fallback", "arrow.uturn.backward.circle.fill", .orange))
        }
        if summary.hasError {
            items.append(("需复核", "exclamationmark.triangle.fill", .red))
        }
        if summary.isCompleted {
            items.append(("完成", "checkmark.circle.fill", .green))
        }
        if summary.hasDuplicateGatewayConnected {
            items.append(("双连接事件", "square.stack.3d.up.fill", .orange))
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: summary.hasError ? "waveform.path.ecg.rectangle.fill" : "antenna.radiowaves.left.and.right.circle.fill")
                    .font(.title3.bold())
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.12), in: Circle())
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 4) {
                    Label("Live Gateway 健康", systemImage: "heart.text.square.fill")
                        .font(.subheadline.bold())
                    Text(summary.compactStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Text(summary.detailLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
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

            if let review = ClawGatewayArtifactMetadataReviewSummary.latest(from: session) {
                ClawGatewayArtifactMetadataReviewRow(review: review)
            }

            if let review = ClawGatewayExtractionCompletenessReviewSummary.latest(from: session) {
                ClawGatewayExtractionCompletenessReviewRow(review: review)
            }

            if let review = ClawGatewayBrowserControlReviewSummary.latest(from: session) {
                ClawGatewayBrowserControlReviewRow(review: review)
            }

            if let review = ClawGatewayDeliverySafetyReviewSummary.latest(from: session) {
                ClawGatewayDeliverySafetyReviewRow(review: review)
            }

            if let review = ClawGatewayCapabilityReviewSummary.latest(from: session) {
                ClawGatewayCapabilityReviewRow(review: review)
            }

            if let review = ClawGatewayAccessibilityReviewSummary.latest(from: session) {
                ClawGatewayAccessibilityReviewRow(review: review)
            }

            if let review = ClawGatewayTaskReplayGuardReviewSummary.latest(from: session) {
                ClawGatewayTaskReplayGuardReviewRow(review: review)
            }

            if let review = ClawAgentTraceReviewSummary.latest(from: session) {
                ClawAgentTraceReviewRow(review: review)
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

            if let review = ClawGatewayArtifactMetadataReviewSummary.latest(from: result.artifacts) {
                ClawGatewayArtifactMetadataReviewRow(review: review)
            }

            if let review = ClawGatewayExtractionCompletenessReviewSummary.latest(from: result.artifacts) {
                ClawGatewayExtractionCompletenessReviewRow(review: review)
            }

            if let review = ClawGatewayBrowserControlReviewSummary.latest(from: result.artifacts) {
                ClawGatewayBrowserControlReviewRow(review: review)
            }

            if let review = ClawGatewayDeliverySafetyReviewSummary.latest(from: result.artifacts) {
                ClawGatewayDeliverySafetyReviewRow(review: review)
            }

            if let review = ClawAgentTraceReviewSummary.latest(from: result.artifacts) {
                ClawAgentTraceReviewRow(review: review)
            }

            if let review = ClawGatewayAccessibilityReviewSummary.latest(from: result.artifacts) {
                ClawGatewayAccessibilityReviewRow(review: review)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ClawGatewayArtifactMetadataReviewRow: View {
    let review: ClawGatewayArtifactMetadataReviewSummary

    private var overviewChips: [(text: String, icon: String, tint: Color)] {
        [
            ("metadata \(review.metadataArtifactCount)/\(review.artifactCount)", "doc.badge.gearshape", review.hasMetadata ? .purple : .secondary),
            ("redacted \(review.redactedArtifactCount)/\(review.artifactCount)", "eye.slash.fill", review.redactedArtifactCount > 0 ? .orange : .secondary),
            (review.latestKind.title, "paperclip", .purple)
        ]
    }

    private var metadataChips: [(text: String, icon: String, tint: Color)] {
        var items = review.safeMetadataPairs.prefix(4).map { pair in
            (text: "\(pair.key)=\(pair.value)", icon: "tag.fill", tint: Color.blue)
        }
        if items.isEmpty {
            items.append((text: "metadata 待同步", icon: "hourglass", tint: .secondary))
        }
        return items
    }

    private var safetyChips: [(text: String, icon: String, tint: Color)] {
        var items = review.safetyFlags.prefix(3).map { flag in
            (text: flag, icon: "shield.lefthalf.filled.badge.checkmark", tint: Color.purple)
        }
        if items.isEmpty {
            items.append((text: "metadata-only", icon: "doc.text.magnifyingglass", tint: .purple))
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("Artifact metadata", systemImage: "doc.text.magnifyingglass")
                    .font(.footnote.bold())
                    .foregroundStyle(.primary)
                PhoneAgentTag(text: "\(review.artifactCount) 条", icon: "number", tint: .purple)
                PhoneAgentTag(
                    text: review.isLatestRedacted ? "已脱敏" : "可见",
                    icon: review.isLatestRedacted ? "eye.slash.fill" : "eye.fill",
                    tint: review.isLatestRedacted ? .orange : .green
                )
                Spacer(minLength: 0)
            }

            Text(review.compactStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(overviewChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(metadataChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(safetyChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ClawGatewayExtractionCompletenessReviewRow: View {
    let review: ClawGatewayExtractionCompletenessReviewSummary

    private var statusTint: Color {
        guard review.hasMetadata else {
            return .secondary
        }
        switch review.completenessStatus {
        case "complete":
            return .green
        case "partial":
            return .orange
        case "empty":
            return .red
        default:
            return .secondary
        }
    }

    private var sourceChips: [(text: String, icon: String, tint: Color)] {
        guard review.hasMetadata else {
            return [("sources 待同步", "hourglass", .secondary)]
        }
        var items: [(String, String, Color)] = []
        if let browserTraceCount = review.browserTraceCount, browserTraceCount > 0 {
            items.append(("browser \(browserTraceCount)", "safari.fill", .blue))
        }
        if let fileDiffCount = review.fileDiffCount, fileDiffCount > 0 {
            items.append(("file \(fileDiffCount)", "doc.text.fill", .purple))
        }
        if let commandOutputCount = review.commandOutputCount, commandOutputCount > 0 {
            items.append(("shell \(commandOutputCount)", "terminal.fill", .orange))
        }
        if let screenObservationCount = review.screenObservationCount, screenObservationCount > 0 {
            items.append(("screen \(screenObservationCount)", "camera.viewfinder", .blue))
        }
        if let accessibilityTreeCount = review.accessibilityTreeCount, accessibilityTreeCount > 0 {
            items.append(("ax \(accessibilityTreeCount)", "accessibility", .green))
        }
        if let messageDraftCount = review.messageDraftCount, messageDraftCount > 0 {
            items.append(("draft \(messageDraftCount)", "text.bubble.fill", .purple))
        }
        if items.isEmpty {
            items.append(("sources 待同步", "hourglass", .secondary))
        }
        return items
    }

    private var safetyChips: [(text: String, icon: String, tint: Color)] {
        guard review.hasMetadata else {
            return [(text: "metadata 待同步", icon: "hourglass", tint: .secondary)]
        }
        var items = review.safetyFlags.prefix(3).map { flag in
            (text: flag, icon: "shield.lefthalf.filled.badge.checkmark", tint: Color.purple)
        }
        if items.isEmpty {
            items.append((text: "metadata-only", icon: "doc.text.magnifyingglass", tint: .purple))
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("提取完整性", systemImage: "checklist.checked")
                    .font(.footnote.bold())
                    .foregroundStyle(.primary)
                PhoneAgentTag(text: "\(review.extractionCount) 条", icon: "number", tint: .purple)
                PhoneAgentTag(
                    text: review.hasMetadata ? (review.completenessStatus ?? "待复核") : "metadata 待同步",
                    icon: review.hasMetadata && review.completenessStatus == "complete" ? "checkmark.seal.fill" : "hourglass",
                    tint: statusTint
                )
                Spacer(minLength: 0)
            }

            Text(review.compactStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    PhoneAgentTag(
                        text: review.hasMetadata ? "rows \(review.rowCount ?? 0)" : "rows 待同步",
                        icon: "tablecells.fill",
                        tint: statusTint
                    )
                    PhoneAgentTag(
                        text: review.hasMetadata ? (review.validateCompleteness == false ? "未校验" : "完整性校验") : "校验待同步",
                        icon: review.hasMetadata && review.validateCompleteness != false ? "checkmark.shield.fill" : "questionmark.diamond.fill",
                        tint: review.hasMetadata ? (review.validateCompleteness == false ? .orange : .green) : .secondary
                    )
                    if let mode = review.mode {
                        PhoneAgentTag(text: mode, icon: "doc.text.magnifyingglass", tint: .blue)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(sourceChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(safetyChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ClawGatewayBrowserControlReviewRow: View {
    let review: ClawGatewayBrowserControlReviewSummary

    private var policyTint: Color {
        guard review.hasMetadata else {
            return .secondary
        }
        return review.networkBlocked == true || review.resultStatus == "failed" ? .orange : .blue
    }

    private var statusChips: [(text: String, icon: String, tint: Color)] {
        guard review.hasMetadata else {
            return [("metadata 待同步", "hourglass", .secondary)]
        }
        var items: [(String, String, Color)] = []
        if let mode = review.mode {
            items.append((mode, "safari.fill", policyTint))
        }
        if let policy = review.browserControlPolicy {
            items.append(("policy \(policy)", "checkmark.shield.fill", policyTint))
        }
        if let resultStatus = review.resultStatus {
            items.append(("result \(resultStatus)", resultStatus == "failed" ? "exclamationmark.triangle.fill" : "checkmark.circle.fill", resultStatus == "failed" ? .orange : .green))
        }
        if items.isEmpty {
            items.append(("metadata 待同步", "hourglass", .secondary))
        }
        return items
    }

    private var controlChips: [(text: String, icon: String, tint: Color)] {
        guard review.hasMetadata else {
            return [("控制计划待同步", "hourglass", .secondary)]
        }
        var items: [(String, String, Color)] = []
        if let browserControlRequested = review.browserControlRequested {
            items.append((browserControlRequested ? "请求打开" : "未请求打开", browserControlRequested ? "arrow.up.forward.app.fill" : "minus.circle.fill", browserControlRequested ? .blue : .secondary))
        }
        if review.targetURLPresent == true {
            items.append(("URL 已省略", "link.badge.plus", .orange))
        }
        if review.searchQueryPresent == true {
            items.append(("搜索词省略", "magnifyingglass", .orange))
        }
        if review.localHTMLInput == true {
            items.append(("HTML 输入省略", "doc.text.magnifyingglass", .orange))
        }
        if items.isEmpty {
            items.append(("输入省略状态待同步", "hourglass", .secondary))
        }
        return items
    }

    private var policyChips: [(text: String, icon: String, tint: Color)] {
        guard review.hasMetadata else {
            return [("allowlist 待同步", "hourglass", .secondary)]
        }
        var items: [(String, String, Color)] = []
        if let networkFetchAttempted = review.networkFetchAttempted {
            items.append((networkFetchAttempted ? "network fetch" : "network 未取回", "network", networkFetchAttempted ? .blue : .secondary))
        }
        if let networkBlocked = review.networkBlocked {
            items.append((networkBlocked ? "network blocked" : "network 未阻断", networkBlocked ? "lock.fill" : "checkmark.circle.fill", networkBlocked ? .orange : .green))
        }
        if let appAllowlistEnforced = review.appAllowlistEnforced {
            items.append((appAllowlistEnforced ? "app allowlist" : "app dry-run", "macwindow.badge.plus", appAllowlistEnforced ? .blue : .secondary))
        }
        if let hostAllowlistEnforced = review.hostAllowlistEnforced {
            items.append((hostAllowlistEnforced ? "host allowlist" : "host dry-run", "globe.badge.chevron.backward", hostAllowlistEnforced ? .blue : .secondary))
        }
        if let executed = review.executed {
            items.append((executed ? "已执行打开" : "未执行打开", executed ? "play.circle.fill" : "pause.circle.fill", executed ? .green : .secondary))
        }
        if items.isEmpty {
            items.append(("策略状态待同步", "hourglass", .secondary))
        }
        return items
    }

    private var safetyChips: [(text: String, icon: String, tint: Color)] {
        guard review.hasMetadata else {
            return [(text: "metadata 待同步", icon: "hourglass", tint: .secondary)]
        }
        var items = review.safetyFlags.prefix(3).map { flag in
            (text: flag, icon: "shield.lefthalf.filled.badge.checkmark", tint: Color.purple)
        }
        if items.isEmpty {
            items.append((text: "metadata-only", icon: "doc.text.magnifyingglass", tint: .purple))
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("Browser Control", systemImage: "safari.fill")
                    .font(.footnote.bold())
                    .foregroundStyle(.primary)
                PhoneAgentTag(text: "\(review.reviewCount) 条", icon: "number", tint: .purple)
                PhoneAgentTag(
                    text: review.hasMetadata ? "metadata-only" : "metadata 待同步",
                    icon: review.hasMetadata ? "doc.text.magnifyingglass" : "hourglass",
                    tint: review.hasMetadata ? .purple : .secondary
                )
                PhoneAgentTag(
                    text: review.isRedacted ? "已脱敏" : "trace 可见",
                    icon: review.isRedacted ? "eye.slash.fill" : "paperclip",
                    tint: review.isRedacted ? .orange : .purple
                )
                Spacer(minLength: 0)
            }

            Text(review.compactStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(statusChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(controlChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(policyChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(safetyChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ClawGatewayDeliverySafetyReviewRow: View {
    let review: ClawGatewayDeliverySafetyReviewSummary

    private var gateTint: Color {
        guard review.hasMetadata else {
            return .secondary
        }
        return review.finalSubmitRequiresApproval == true || review.submitBlocked == true ? .orange : .secondary
    }

    private var statusChips: [(text: String, icon: String, tint: Color)] {
        guard review.hasMetadata else {
            return [("metadata 待同步", "hourglass", .secondary)]
        }
        var items: [(String, String, Color)] = []
        if let mode = review.mode {
            items.append((mode, "hand.raised.fill", gateTint))
        }
        if let actionKind = review.actionKind {
            items.append((actionKind, "square.stack.3d.forward.dottedline", .blue))
        }
        if let targetKind = review.targetKind {
            items.append((targetKind, targetKind == "desktopApp" ? "macwindow.badge.plus" : "text.bubble.fill", .purple))
        }
        if items.isEmpty {
            items.append(("metadata 待同步", "hourglass", .secondary))
        }
        return items
    }

    private var omissionChips: [(text: String, icon: String, tint: Color)] {
        guard review.hasMetadata else {
            return [("正文待同步", "hourglass", .secondary)]
        }
        var items: [(String, String, Color)] = []
        if let draftBodyOmitted = review.draftBodyOmitted {
            items.append((draftBodyOmitted ? "正文省略" : "正文待复核", draftBodyOmitted ? "eye.slash.fill" : "questionmark.diamond.fill", draftBodyOmitted ? .orange : .secondary))
        }
        if let pasteTextOmitted = review.pasteTextOmitted {
            items.append((pasteTextOmitted ? "paste 省略" : "paste 未使用", pasteTextOmitted ? "eye.slash.fill" : "minus.circle.fill", pasteTextOmitted ? .orange : .secondary))
        }
        if let blockedSubmitKeyCount = review.blockedSubmitKeyCount {
            items.append(("submit keys \(blockedSubmitKeyCount)", "keyboard.badge.ellipsis", blockedSubmitKeyCount > 0 ? .orange : .secondary))
        }
        if let blockedKeyCount = review.blockedKeyCount {
            items.append(("blocked \(blockedKeyCount)", "lock.trianglebadge.exclamationmark.fill", blockedKeyCount > 0 ? .orange : .secondary))
        }
        if let allowedKeyCount = review.allowedKeyCount {
            items.append(("allowed \(allowedKeyCount)", "keyboard", .blue))
        }
        if items.isEmpty {
            items.append(("省略状态待同步", "hourglass", .secondary))
        }
        return items
    }

    private var safetyChips: [(text: String, icon: String, tint: Color)] {
        guard review.hasMetadata else {
            return [(text: "metadata 待同步", icon: "hourglass", tint: .secondary)]
        }
        var items = review.safetyFlags.prefix(3).map { flag in
            (text: flag, icon: "shield.lefthalf.filled.badge.checkmark", tint: Color.purple)
        }
        if items.isEmpty {
            items.append((text: "metadata-only", icon: "doc.text.magnifyingglass", tint: .purple))
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("Delivery Safety", systemImage: "hand.raised.fill")
                    .font(.footnote.bold())
                    .foregroundStyle(.primary)
                PhoneAgentTag(text: "\(review.reviewCount) 条", icon: "number", tint: .purple)
                PhoneAgentTag(
                    text: review.userApprovalRequired == true ? "需确认" : "确认待复核",
                    icon: review.userApprovalRequired == true ? "checkmark.seal.fill" : "hourglass",
                    tint: review.userApprovalRequired == true ? .orange : .secondary
                )
                PhoneAgentTag(
                    text: review.isRedacted ? "已脱敏" : "可见",
                    icon: review.isRedacted ? "eye.slash.fill" : "eye.fill",
                    tint: review.isRedacted ? .orange : .green
                )
                Spacer(minLength: 0)
            }

            Text(review.compactStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(statusChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(omissionChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(safetyChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ClawGatewayCapabilityReviewRow: View {
    let review: ClawGatewayCapabilityReviewSummary

    private var stateChips: [(text: String, icon: String, tint: Color)] {
        var items: [(String, String, Color)] = []
        if let workspace = review.workspaceState {
            items.append(("workspace \(workspace)", "folder.badge.gearshape", tint(for: workspace)))
        }
        if let shell = review.shellState {
            items.append(("shell \(shell)", "terminal.fill", tint(for: shell)))
        }
        if let browser = review.browserControlState {
            items.append(("browser \(browser)", "safari.fill", tint(for: browser)))
        }
        if let network = review.browserNetworkState {
            items.append(("network \(network)", "network", tint(for: network)))
        }
        if let desktop = review.desktopControlState {
            items.append(("desktop \(desktop)", "macwindow.badge.plus", tint(for: desktop)))
        }
        if let screen = review.screenCaptureState {
            items.append(("screen \(screen)", "camera.viewfinder", tint(for: screen)))
        }
        if let window = review.windowMetadataState {
            items.append(("window \(window)", "macwindow", tint(for: window)))
        }
        if let accessibility = review.accessibilityTreeState {
            items.append(("ax \(accessibility)", "accessibility", tint(for: accessibility)))
        }
        if items.isEmpty {
            items.append(("metadata 待同步", "hourglass", .secondary))
        }
        return items
    }

    private var safetyChips: [(text: String, icon: String, tint: Color)] {
        var items = review.safetyFlags.prefix(3).map { flag in
            (text: flag, icon: "shield.lefthalf.filled.badge.checkmark", tint: Color.purple)
        }
        if items.isEmpty {
            items.append((text: "审计复核", icon: "checkmark.shield.fill", tint: .purple))
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("Gateway 能力", systemImage: "server.rack")
                    .font(.footnote.bold())
                    .foregroundStyle(.primary)
                PhoneAgentTag(text: "\(review.snapshotCount) 条", icon: "number", tint: .purple)
                PhoneAgentTag(
                    text: review.isRedacted ? "已脱敏" : "可见",
                    icon: review.isRedacted ? "eye.slash.fill" : "eye.fill",
                    tint: review.isRedacted ? .orange : .green
                )
                Spacer(minLength: 0)
            }

            Text(review.compactStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(stateChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if let fingerprint = review.tokenFingerprint {
                        PhoneAgentTag(text: fingerprint, icon: "key.fill", tint: .purple)
                    }
                    if review.tokenConfigured == true {
                        PhoneAgentTag(text: review.tokenRequired == true ? "token required" : "token configured", icon: "lock.shield.fill", tint: .purple)
                    }
                    ForEach(Array(review.allowedActionKinds.prefix(3)), id: \.self) { kind in
                        PhoneAgentTag(text: kind, icon: "square.stack.3d.forward.dottedline", tint: .blue)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(safetyChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func tint(for state: String) -> Color {
        switch state {
        case "real":
            return .green
        case "workspace-only":
            return .purple
        case "dry-run":
            return .blue
        case "disabled":
            return .secondary
        case "unavailable":
            return .orange
        default:
            return .secondary
        }
    }
}

struct ClawGatewayAccessibilityReviewRow: View {
    let review: ClawGatewayAccessibilityReviewSummary

    private var statusChips: [(text: String, icon: String, tint: Color)] {
        var items: [(String, String, Color)] = []
        if let mode = review.mode {
            items.append(("mode \(mode)", "accessibility", tint(forMode: mode)))
        }
        if let policy = review.accessibilityPolicy {
            items.append(("policy \(policy)", "checkmark.shield.fill", tint(forMode: policy)))
        }
        if let candidateControlCount = review.candidateControlCount {
            if let maxCandidateControls = review.maxCandidateControls {
                items.append(("controls \(candidateControlCount)/\(maxCandidateControls)", "point.3.connected.trianglepath.dotted", .purple))
            } else {
                items.append(("controls \(candidateControlCount)", "point.3.connected.trianglepath.dotted", .purple))
            }
        }
        if let nodeCount = review.nodeCount {
            items.append(("nodes \(nodeCount)", "square.stack.3d.up.fill", .blue))
        }
        if items.isEmpty {
            items.append(("metadata 待同步", "hourglass", .secondary))
        }
        return items
    }

    private var detailChips: [(text: String, icon: String, tint: Color)] {
        var items: [(String, String, Color)] = []
        if let platform = review.platform {
            items.append((platform, "desktopcomputer", .purple))
        }
        if let redaction = review.redaction {
            items.append(("redaction \(redaction)", "eye.slash.fill", .orange))
        }
        if let include = review.includeAccessibilityTree {
            items.append((include ? "tree requested" : "tree skipped", include ? "checkmark.circle.fill" : "minus.circle.fill", include ? .green : .secondary))
        }
        return items
    }

    private var safetyChips: [(text: String, icon: String, tint: Color)] {
        var items = review.safetyFlags.prefix(3).map { flag in
            (text: flag, icon: "shield.lefthalf.filled.badge.checkmark", tint: Color.purple)
        }
        if items.isEmpty {
            items.append((text: "metadata-only", icon: "doc.text.magnifyingglass", tint: .purple))
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("Accessibility", systemImage: "accessibility")
                    .font(.footnote.bold())
                    .foregroundStyle(.primary)
                PhoneAgentTag(text: "\(review.treeCount) 条", icon: "number", tint: .purple)
                PhoneAgentTag(
                    text: review.isRedacted ? "已脱敏" : "可见",
                    icon: review.isRedacted ? "eye.slash.fill" : "eye.fill",
                    tint: review.isRedacted ? .orange : .green
                )
                Spacer(minLength: 0)
            }

            Text(review.compactStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(statusChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }

            if detailChips.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(detailChips.enumerated()), id: \.offset) { _, chip in
                            PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(safetyChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func tint(forMode mode: String) -> Color {
        switch mode {
        case "accessibility-summary", "enabled":
            return .green
        case "dry-run", "window-metadata":
            return .blue
        case "accessibility-failed":
            return .red
        case "accessibility-unavailable":
            return .orange
        case "not-requested", "disabled":
            return .secondary
        default:
            return .secondary
        }
    }
}

struct ClawGatewayTaskReplayGuardReviewRow: View {
    let review: ClawGatewayTaskReplayGuardReviewSummary

    private var statusChips: [(text: String, icon: String, tint: Color)] {
        var items: [(String, String, Color)] = []
        if let replayCount = review.replayCount {
            items.append(("replay \(replayCount)", "arrow.clockwise.circle.fill", .orange))
        }
        if let actionCount = review.actionCount {
            items.append(("skipped \(actionCount)", "forward.end.fill", .orange))
        }
        if let originalStatus = review.originalStatus {
            items.append(("first \(originalStatus)", "clock.badge.checkmark.fill", tint(forStatus: originalStatus)))
        }
        if let matches = review.digestMatchesFirst {
            items.append((matches ? "digest match" : "digest changed", matches ? "checkmark.seal.fill" : "exclamationmark.triangle.fill", matches ? .green : .red))
        }
        if let digest = review.shortReplayDigest {
            items.append((digest, "number", .purple))
        }
        if items.isEmpty {
            items.append(("metadata 待同步", "hourglass", .secondary))
        }
        return items
    }

    private var identityChips: [(text: String, icon: String, tint: Color)] {
        var items: [(String, String, Color)] = []
        if let taskID = review.shortTaskID {
            items.append(("task \(taskID)", "doc.badge.gearshape", .purple))
        }
        if let firstSessionID = review.shortFirstSessionID {
            items.append(("first \(firstSessionID)", "rectangle.stack.badge.person.crop", .purple))
        }
        for kind in review.actionKinds.prefix(3) {
            items.append((kind, "square.stack.3d.forward.dottedline", .blue))
        }
        return items
    }

    private var safetyChips: [(text: String, icon: String, tint: Color)] {
        var items = review.safetyFlags.prefix(3).map { flag in
            (text: flag, icon: "shield.lefthalf.filled.badge.checkmark", tint: Color.purple)
        }
        if items.isEmpty {
            items.append((text: "process-local", icon: "desktopcomputer.trianglebadge.exclamationmark", tint: .orange))
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("Replay Guard", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.footnote.bold())
                    .foregroundStyle(.primary)
                PhoneAgentTag(text: "\(review.replayCountArtifacts) 条", icon: "number", tint: .orange)
                PhoneAgentTag(
                    text: review.isRedacted ? "已脱敏" : "可见",
                    icon: review.isRedacted ? "eye.slash.fill" : "eye.fill",
                    tint: review.isRedacted ? .orange : .green
                )
                Spacer(minLength: 0)
            }

            Text(review.compactStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(statusChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }

            if identityChips.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(identityChips.enumerated()), id: \.offset) { _, chip in
                            PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(safetyChips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func tint(forStatus status: String) -> Color {
        switch status {
        case "completed":
            return .green
        case "running":
            return .blue
        case "failed":
            return .red
        default:
            return .secondary
        }
    }
}

struct ClawAgentTraceReviewRow: View {
    let review: ClawAgentTraceReviewSummary

    private var chips: [(text: String, icon: String, tint: Color)] {
        var items: [(String, String, Color)] = []
        if let score = review.readinessScore {
            items.append(("证据 \(score)/100", "gauge.with.dots.needle.67percent", score >= 70 ? .green : .orange))
        }
        if review.missingSignals.isEmpty == false {
            items.append(("缺 \(review.missingSignals.prefix(2).joined(separator: ","))", "exclamationmark.triangle.fill", .orange))
        }
        if let action = review.selectedNextActionKind {
            let icon = review.selectedNextActionRequiresApproval == true ? "checkmark.seal.fill" : "arrow.forward.circle.fill"
            items.append((action, icon, review.selectedNextActionRequiresApproval == true ? .orange : .blue))
        }
        if let stop = review.stopReason {
            items.append((stop, "hand.raised.fill", stop == "none" || stop == "complete" ? .green : .red))
        }
        if let risk = review.riskTags.first {
            items.append((risk, "shield.lefthalf.filled.badge.checkmark", .purple))
        }
        if items.isEmpty {
            items.append(("metadata 待同步", "hourglass", .secondary))
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("AgentTrace", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.footnote.bold())
                    .foregroundStyle(.primary)
                PhoneAgentTag(text: "\(review.traceCount) 条", icon: "number", tint: .purple)
                PhoneAgentTag(
                    text: review.isRedacted ? "已脱敏" : "可见",
                    icon: review.isRedacted ? "eye.slash.fill" : "eye.fill",
                    tint: review.isRedacted ? .orange : .green
                )
                Spacer(minLength: 0)
            }

            Text(review.compactStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                        PhoneAgentTag(text: chip.text, icon: chip.icon, tint: chip.tint)
                    }
                }
            }

            if let handoffSummary = review.handoffSummary {
                Text(handoffSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
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
