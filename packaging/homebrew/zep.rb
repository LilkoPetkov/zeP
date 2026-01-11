class Zep < Formula
  desc "Fast package manager for Zig"
  homepage "https://github.com/XerWoho/zeP"
  license "GPLv3"

  on_macos do
    url "https://zep.run/releases/1.0.2/zep_x86_64-macos_1.0.2.tar.xz"
    sha256 "11671f4b6423f2e1ec023f211b8d9439c085dd8598b5bcda7fa2552cd798ae8a"
  end

  on_linux do
    url "https://zep.run/releases/1.0.2/zep_x86_64-linux_1.0.2.tar.xz"
    sha256 "5bb76c0441a5f08a412ca3dd65209a1714bf04adb6ec57aea13a6e924e4307fe"
  end

  def install
    bin.install "zep" => "zep"
  end

    def post_install
		ohai "--- ZEP CONFIG REQUIRED ---"
		puts " ==> Run 'zep setup' to configure zep"
		puts " ==> Then run: zep zep install 1.0.2"
	end

  test do
    system "#{bin}/zep", "version"
  end
end
