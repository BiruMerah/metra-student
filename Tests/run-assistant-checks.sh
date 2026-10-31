#!/bin/zsh
set -euo pipefail
task_repo_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
task_check_dir="$(mktemp -d "${TMPDIR:-/tmp}/metra-assistant-checks.XXXXXX")"
trap 'rm -rf "$task_check_dir"' EXIT
cd "$task_repo_root"

xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
  -module-cache-path "$task_check_dir/cache" \
  MetraStudent/Domain/Models/MathTopicModel.swift \
  MetraStudent/Domain/Models/MetraAssistantModels.swift \
  MetraStudent/Domain/Protocols/MetraAssistantProtocol.swift \
  MetraStudent/Presentation/Helpers/TopicSentenceChunker.swift \
  MetraStudent/Presentation/ViewModels/TopicViewModel.swift \
  MetraStudent/Data/Managers/FoundationMetraAssistantModel.swift \
  MetraStudent/Data/Managers/MetraAssistantPipeline.swift \
  MetraStudent/Data/Managers/MetraTranslationBridge.swift \
  MetraStudent/Presentation/ViewModels/MetraAssistantViewModel.swift \
  Tests/AssistantLogicChecks.swift \
  -o "$task_check_dir/checks"
"$task_check_dir/checks"
