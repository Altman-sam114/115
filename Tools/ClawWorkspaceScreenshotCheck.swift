import CoreGraphics
import Darwin
import Foundation
import ImageIO
import Vision

private func containsWorkspaceContent(_ lines: [String]) -> Bool {
    let text = lines.joined().lowercased().filter { $0.isLetter }
    return text.contains("claw") && text.contains("missionrun")
}

private func isWorkspaceReady(_ image: CGImage) throws -> Bool {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-US"]
    request.usesLanguageCorrection = false
    request.minimumTextHeight = 0.006
    try VNImageRequestHandler(cgImage: image).perform([request])
    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    // OCR text can include user input. Only the fixed readiness result may leave this function.
    return containsWorkspaceContent(lines)
}

private func selfTest() throws -> Bool {
    guard !containsWorkspaceContent([]),
          !containsWorkspaceContent(["Claw Agent"]),
          !containsWorkspaceContent(["Mission Run"]),
          !containsWorkspaceContent(["3:17 PM", "Thu Oct 22", "100%"]),
          containsWorkspaceContent(["Claw Agent", "Mission Run"]),
          containsWorkspaceContent(["OpenClaw", "Mission", "Run"]),
          let context = CGContext(
            data: nil, width: 320, height: 480,
            bitsPerComponent: 8, bytesPerRow: 320 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          ) else { return false }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 320, height: 480))
    guard let blank = context.makeImage() else { return false }
    let ready = try isWorkspaceReady(blank)
    return !ready
}

do {
    guard CommandLine.arguments.count == 2 else {
        print("workspace_screenshot_invalid_arguments")
        exit(1)
    }
    if CommandLine.arguments[1] == "--self-test" {
        guard try selfTest() else {
            print("workspace_screenshot_self_test_failed")
            exit(1)
        }
        print("Workspace screenshot validator self-test passed")
        exit(0)
    }
    let url = URL(fileURLWithPath: CommandLine.arguments[1])
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        print("workspace_screenshot_unreadable")
        exit(1)
    }
    guard try isWorkspaceReady(image) else {
        print("workspace_content_not_ready")
        exit(2)
    }
    print("workspace_content_ready")
} catch {
    print("workspace_screenshot_validation_failed")
    exit(1)
}
