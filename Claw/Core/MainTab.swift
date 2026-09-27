enum MainTab: String, CaseIterable, Identifiable, Sendable {
    case phoneAgent
    case link
    case chat
    case skills
    case ranking

    var id: Self { self }

    var title: String {
        switch self {
        case .phoneAgent: "任务工作台"
        case .link: "连接与模型"
        case .chat: "聊天"
        case .skills: "能力库"
        case .ranking: "模型参考"
        }
    }

    var icon: String {
        switch self {
        case .phoneAgent: "display.and.arrow.down"
        case .link: "rectangle.connected.to.line.below"
        case .chat: "bubble.left.and.text.bubble.right.fill"
        case .skills: "square.grid.2x2.fill"
        case .ranking: "chart.bar.xaxis"
        }
    }

    var shortcut: Character {
        switch self {
        case .phoneAgent: "1"
        case .link: "2"
        case .chat: "3"
        case .skills: "4"
        case .ranking: "5"
        }
    }
}
