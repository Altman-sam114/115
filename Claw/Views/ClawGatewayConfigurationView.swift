import SwiftUI

struct ClawGatewayConfigurationView: View {
    @EnvironmentObject private var store: ClawStore
    @State private var confirmsClear = false
    @State private var confirmsReload = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("wss://your-gateway 或 ws://127.0.0.1:18789", text: $store.gatewayURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)
                .privacySensitive()
                .accessibilityLabel("网关地址草稿")

            SecureField("Gateway Token", text: $store.gatewayToken)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .privacySensitive()
                .accessibilityLabel("网关凭据草稿")
                .accessibilityHint("保存前不作为运行时凭据使用；不会显示或发送到旧地址。")

            Label(store.gatewayConfigurationState.message, systemImage: "key.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if store.gatewayHasUnappliedChanges {
                Label("有未保存更改：模型、探测、readiness 和任务发送均暂停，直到明确保存或还原。", systemImage: "exclamationmark.shield.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                store.saveGatewayConfiguration()
            } label: {
                Label("保存到本机 Keychain", systemImage: "checkmark.seal.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .accessibilityHint("原子保存地址与凭据，不连接网关、不审批或发送任务。保存失败不替换原连接。")

            ViewThatFits(in: .horizontal) {
                HStack { restoreButton; reloadButton }
                VStack { restoreButton; reloadButton }
            }

            Button(role: .destructive) { confirmsClear = true } label: {
                Label("清除本机连接", systemImage: "trash")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityHint("确认后只清本机记录和运行时凭据，不撤销远端 Token 或已发送的电脑动作。")

            Text("仅本设备、解锁时可读，不通过 iCloud 同步。远端连接必须使用可信 WSS；保存配置不代表已配对或已授权电脑操作。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .panelCard()
        .confirmationDialog("丢弃当前连接草稿并重新读取 Keychain？", isPresented: $confirmsReload, titleVisibility: .visible) {
            Button("重新读取") { store.reloadSavedGatewayConfiguration() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("成功读取后会替换本机连接并使旧审批失效；不会自动连接或恢复任务。读取失败保留当前已应用配置。")
        }
        .alert("清除本机连接？", isPresented: $confirmsClear) {
            Button("清除", role: .destructive) { store.clearSavedGatewayConfiguration() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("成功后将清除地址与 Token，并使旧审批和续接授权失效。不会停止已发送任务或撤销远端凭据；远端撤销需在 Gateway 操作。")
        }
    }

    private var restoreButton: some View {
        Button { store.discardGatewayConfigurationDraft() } label: {
            Label("还原未保存更改", systemImage: "arrow.uturn.backward")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(!store.gatewayHasUnappliedChanges)
        .accessibilityHint("只还原到当前进程已应用的连接，不读写 Keychain，不恢复旧审批，也不联网。")
    }

    private var reloadButton: some View {
        Button { confirmsReload = true } label: {
            Label("重新读取已保存连接", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("需确认丢弃草稿；只读取本机存储，不连接网关或恢复上次任务。")
    }
}
