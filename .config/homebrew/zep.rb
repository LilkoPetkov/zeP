class Zep < Formula
  desc "Fast package manager for Zig"
  homepage "https://github.com/XerWoho/zeP"
  license "GPLv3"

  on_macos do
    url "https://zep.run/releases/1.0.1/zep_x86_64-macos_1.0.1.tar.xz"
    sha256 "21020e2d2bc84145b1e70e29bec917540cbeaeb8a1a1e82e57a30200694b3ae3"
  end

  on_linux do
    url "https://zep.run/releases/1.0.1/zep_x86_64-linux_1.0.1.tar.xz"
    sha256 "5437049f8cceb2183ea0549d49e1198bd6331077f23ebefd720d85edf206f272"
  end

  def install
    bin.install "zep" => "zep"
  end

    def post_install
		ohai "--- ZEP CONFIG REQUIRED ---"
		puts " ==> Run 'zep setup' to configure zep"
		puts " ==> Then run: zep zep install 1.0.1"
	end

  test do
    system "#{bin}/zep", "version"
  end
end
