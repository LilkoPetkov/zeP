class Zep < Formula
  desc "Fast package manager for Zig"
  homepage "https://github.com/XerWoho/zeP"
  license "GPLv3"

  on_macos do
    url "https://zep.run/releases/1.2.0/zep_x86_64-macos_1.2.0.tar.xz"
    sha256 "24f3cf9a844254bbb37601010eea618343b80f09d345939dc3fb99ebcdc0995d"
  end

  on_linux do
    url "https://zep.run/releases/1.2.0/zep_x86_64-linux_1.2.0.tar.xz"
    sha256 "4713b33b59e0fe627e6aebe5ab202043da83c32b76fd710262b1c265efd28616"
  end

  def install
    bin.install "zep" => "zep"
  end

  test do
    system "#{bin}/zep", "version"
  end
end
