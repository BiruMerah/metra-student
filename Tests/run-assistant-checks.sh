#!/bin/zsh
set -euo pipefail
task_repo_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
task_check_dir="$(mktemp -d "${TMPDIR:-/tmp}/metra-assistant-checks.XXXXXX")"
trap 'rm -rf "$task_check_dir"' EXIT
cd "$task_repo_root"

xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
  -module-cache-path "$task_check_dir/cache" \
  MetraStudent/Domain/Models/MathSectionModel.swift \
  MetraStudent/Domain/Models/AIAssistantModel.swift \
  MetraStudent/Domain/Protocols/AIAssistant/AssistantGeneratingProtocol.swift \
  MetraStudent/Domain/Protocols/AIAssistant/AssistantVoiceCapturingProtocol.swift \
  MetraStudent/Domain/Helpers/TopicSentenceChunker.swift \
  MetraStudent/Presentation/Section/ViewModels/SectionViewModel.swift \
  MetraStudent/Data/AISources/FoundationModel.swift \
  MetraStudent/Data/AISources/MetraSpeechCapture.swift \
  MetraStudent/Presentation/AIAssistant/ViewModels/AIAssistantViewModel.swift \
  Tests/AssistantLogicChecks.swift \
  -o "$task_check_dir/checks"
"$task_check_dir/checks"
