# source before swift build/test/run
#
#   source Tools/env.sh
#
# 1. CLT swiftpm is broken, use swiftly toolchain
# 2. xcode-select points at unfinished Xcode, DEVELOPER_DIR pins CLT
# 3. ~/Documents is icloud, codesign chokes on xattrs so build elsewhere
#
# Usage: swift build --scratch-path "$FLOW_SCRATCH_PATH"
#        swift test  --scratch-path "$FLOW_SCRATCH_PATH"
# (no shell wrapper, --scratch-path isn't valid for every subcommand)

export DEVELOPER_DIR=/Library/Developer/CommandLineTools
source "$HOME/.swiftly/env.sh"

export FLOW_SCRATCH_PATH="$HOME/.cache/flow-build"
mkdir -p "$FLOW_SCRATCH_PATH"
