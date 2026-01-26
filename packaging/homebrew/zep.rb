class Zep < Formula
  desc "Fast package manager for Zig"
  homepage "https://github.com/XerWoho/zeP"
  license "GPLv3"

  on_macos do
    url "https://zep.run/releases/1.1.0/zep_x86_64-macos_1.1.0.tar.xz"
    sha256 "ab5a1e16e8f431316a4cb1c571d26ce4d435d2a29caa766381984e65be992b24"
  end

  on_linux do
    url "https://zep.run/releases/1.1.0/zep_x86_64-linux_1.1.0.tar.xz"
    sha256 "5ad4cf09545abb7ca7d52c61441108c0022459ade91d7d938f5eca012e0ed4c6"
  end

  def install
    bin.install "zep" => "zep"
  end

  test do
    system "#{bin}/zep", "version"
  end
end
