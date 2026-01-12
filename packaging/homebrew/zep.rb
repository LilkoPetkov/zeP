class Zep < Formula
  desc "Fast package manager for Zig"
  homepage "https://github.com/XerWoho/zeP"
  license "GPLv3"

  on_macos do
    url "https://zep.run/releases/1.0.2/zep_x86_64-macos_1.0.2.tar.xz"
    sha256 "477e8d5c6a8a6f848dbc8e77269564b12ebf140889d5e6e2968755444b29efa4"
  end

  on_linux do
    url "https://zep.run/releases/1.0.2/zep_x86_64-linux_1.0.2.tar.xz"
    sha256 "078a36b01ad49297439094bb45aacec240e79db3f7629085e1d523134da800c9"
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
