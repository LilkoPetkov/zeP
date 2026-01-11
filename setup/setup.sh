curl -fsSL https://zep.run/installer/installer.sh | bash
zep install

if ! command -v zig >/dev/null 2>&1
then
    echo "zig could not be found"
    echo "SUGGESTION:"
    echo " $ zep zig install 0.15.2"
    exit 1
fi

zig_version=`zig version`

if ! [ zig_version = "0.15.2" ]; then
    echo "zig version is not compatible with zeP"
    echo "SUGGESTION:"
    echo " $ zep zig install 0.15.2"
    exit 1
fi
