const std = @import("std");
const expect = std.testing.expect;

const io = @import("io");

test "fs existence checker" {
    const does_not_exist = io.Fs.existsFile("tests/assets/does_not_exist.txt");
    try expect(!does_not_exist);

    const does_exist = io.Fs.existsFile("tests/assets/exists.txt");
    try expect(does_exist);
}

test "fs creation checker" {
    const test_path = "tests/assets/created.txt";
    if (io.Fs.existsFile(test_path)) {
        try io.Fs.deleteFileIfExists(test_path);
    }
    try expect(!io.Fs.existsFile(test_path));

    _ = try io.Fs.openOrCreateFile(test_path);
    try expect(io.Fs.existsFile(test_path));

    _ = try io.Fs.deleteFileIfExists(test_path);
    try expect(!io.Fs.existsFile(test_path));
}
