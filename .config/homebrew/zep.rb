class Zep < Formula
  desc "Fast package manager for Zig"
  homepage "https://github.com/XerWoho/zeP"
  license "GPLv3"

  on_macos do
    url "https://zep.run/releases/1.0.0/zep_x86_64-macos_1.0.0.tar.xz"
    sha256 "07acc4a4e781ca025d28e9d0c664769a2ccf789e76e25f1aac90ac68eff5f8c0"
  end

  on_linux do
    url "https://zep.run/releases/1.0.0/zep_x86_64-linux_1.0.0.tar.xz"
    sha256 "e7d716524f3cb59eac7ebbcd5afd09cdeee7493a83849407ee3172dd983721d9"
  end

  def install
    bin.install "zep" => "zep"
  end

    def post_install
		ohai "--- ZEP CONFIG REQUIRED ---"
		puts " ==> Run 'zep setup' to configure zep"
		puts " ==> Then run: zep zep install 1.0.0"
	end

  test do
    system "#{bin}/zep", "version"
  end
end
