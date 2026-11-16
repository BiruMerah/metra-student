#!/bin/zsh
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
task_project_dir="${0:A:h:h}"
task_check_dir="$(mktemp -d /tmp/metra-student-invitations.XXXXXX)"
trap 'rm -rf "$task_check_dir"' EXIT
xcrun swiftc -parse-as-library -module-cache-path "$task_check_dir/module-cache" \
  "$task_project_dir/MetraStudent/Domain/Models/ClassroomChannelModel.swift" \
  "$task_project_dir/MetraStudent/Domain/Models/ClassroomInvitationLink.swift" \
  "$task_project_dir/MetraStudent/Domain/Models/ClassroomInvitationValidation.swift" \
  "$task_project_dir/MetraStudent/Domain/Models/ReceivedClassroomInvitation.swift" \
  "$task_project_dir/MetraStudent/App/ClassroomInvitationInbox.swift" \
  "$task_project_dir/MetraStudent/Presentation/Home/ViewModels/StudentClassroomInvitationViewModel.swift" \
  "$task_project_dir/Tests/ClassroomInvitationChecks.swift" -o "$task_check_dir/checks"
"$task_check_dir/checks"
