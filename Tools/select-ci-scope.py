#!/usr/bin/env python3
"""Conservative CI selection; unknown or validation-infrastructure edits run full."""
import argparse
import json
import os
from pathlib import Path
import subprocess

FULL_CHECKS = {
    "git-diff-check", "plutil", "node-check", "swift-logic-smoke",
    "swift-gateway-fixture", "gateway-direct-smoke", "gateway-websocket-smoke",
    "model-planning-smoke", "artifact-preview-smoke", "xcodebuild", "xctest",
    "mac-catalyst-release", "ipad-xctest", "workspace-screenshot-check",
}
WORKSPACE_CHECKS = {
    "git-diff-check", "plutil", "xcodebuild", "xctest", "mac-catalyst-release",
    "ipad-xctest", "workspace-screenshot-check",
}
WORKSPACE_FILES = {
    "Claw/Core/MainTab.swift", "Claw/Core/ClawWorkspaceLayout.swift",
    "Claw/Views/PhoneAgentCommandPanel.swift", "Claw/Views/PhoneAgentView.swift",
    "Claw/Views/PhoneAgentCompactLayout.swift", "Claw/Views/PhoneAgentWorkbenchLayout.swift",
    "Claw/Views/ClawDestinationView.swift",
}
WORKSPACE_TESTS = [
    "testWorkspaceDetailNavigationContract",
    "testWorkspaceResultSourceUsesSessionFactsInsteadOfCurrentDispatchSetting",
    "testWorkspacePresentationStateDoesNotMutateMissionOrAuthorization",
    "testContinuationEditorUnappliedInputsSurviveLayoutChangesAndStoreRefresh",
    "testContinuationEditorRejectsStaleScopeAndClearsUnavailableInputs",
    "testContinuationEditorRebindsKindWithoutLeakingOtherFields",
    "testWorkspacePendingEditorCannotMutateTrustedContinuationBeforeExplicitApply",
    "testWorkbenchAdaptsToActualWindowAndAccessibilitySize",
    "testWorkspaceDestinationsHaveUniqueStableShortcuts",
]


def select(files):
    relevant = [name for name in files if not name.endswith(".md")]
    # Build settings, shared tests, protocol, Store and CI changes deliberately stay full.
    if relevant and all(name in WORKSPACE_FILES for name in relevant):
        profile = "workspace"
        selected = WORKSPACE_CHECKS
        reason = "Only allowlisted presentation files changed; execution contracts unchanged."
    else:
        profile = "full"
        selected = FULL_CHECKS
        reason = "Unknown, shared, build/test infrastructure or empty change range requires full validation."
    return {
        "policy": "claw-ci-scope-v1", "profile": profile, "reason": reason,
        "changedFiles": files, "selectedChecks": sorted(selected),
        "skippedChecks": sorted(FULL_CHECKS - selected),
        "selectedTests": WORKSPACE_TESTS if profile == "workspace" else [],
    }


def self_test():
    assert select(["Claw/Views/PhoneAgentView.swift"])["profile"] == "workspace"
    assert select(["Claw/Views/PhoneAgentView.swift", "README.md"])["profile"] == "workspace"
    for name in ["Claw/Services/ClawStore.swift", "Tools/claw-gateway-server.mjs",
                 "Claw/Core/ClawModels.swift", "ClawTests/ClawTests.swift",
                 "Claw.xcodeproj/project.pbxproj", ".github/workflows/ci-results.yml",
                 "Tools/select-ci-scope.py", "unknown", "Claw/Views/Foo.swift/escape",
                 "Claw/Views/ContentView.swift", "Claw/Views/ClawTaskArgumentsEditor.swift",
                 "Claw/Views/ClawGatewayConfigurationView.swift", "Claw/App/ClawApp.swift",
                 "Claw/Views/Unknown.swift"]:
        assert select(["Claw/Views/PhoneAgentView.swift", name])["profile"] == "full"
    for files in [[], ["README.md"]]:
        assert select(files)["profile"] == "full"
    assert not WORKSPACE_CHECKS - FULL_CHECKS
    assert len(WORKSPACE_TESTS) == len(set(WORKSPACE_TESTS)) == 9
    source = Path("ClawTests/ClawTests.swift").read_text()
    assert all(f"func {name}(" in source for name in WORKSPACE_TESTS)
    assert select(["Claw/Core/MainTab.swift"])["selectedTests"] == WORKSPACE_TESTS
    print("CI scope selection self-test passed (unknown/shared/CI edits fail closed to full).")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    args = parser.parse_args()
    self_test()
    try:
        files = subprocess.check_output(
            ["git", "diff", "--name-only", "-z", args.base, "HEAD"],
        ).decode().rstrip("\0").split("\0")
        files = [name for name in files if name]
    except (subprocess.CalledProcessError, UnicodeError):
        files = []
    result = select(files)
    result.update(commitSha=os.environ["GITHUB_SHA"], runId=os.environ["GITHUB_RUN_ID"],
                  runAttempt=os.environ["GITHUB_RUN_ATTEMPT"])
    directory = Path(os.environ["RESULT_DIR"])
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "ci-selection.json").write_text(json.dumps(result, indent=2) + "\n")
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"profile={result['profile']}\n")
    # Each line is a fixed test identifier, never code or user input.
    test_arguments = "".join(f"-only-testing:ClawTests/ClawTests/{name}\n" for name in result["selectedTests"])
    (directory / "workspace-tests.txt").write_text(test_arguments or "-only-testing:ClawTests\n")
    print(f"Selected {result['profile']}: {result['reason']}")


if __name__ == "__main__":
    main()
