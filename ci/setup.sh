curl -fsSL https://zep.run/installer/installer.sh | bash

USR_LOCAL_BIN="$HOME/.local/bin"
ZEP_EXE="$USR_LOCAL_BIN/zep"


ZEP_EXE setup
ZEP_EXE zig install 0.15.2