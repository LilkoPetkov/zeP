class Zep < Formula
  desc "Fast package manager for Zig"
  homepage "https://github.com/XerWoho/zeP"
  license "GPLv3"

  on_macos do
    url "https://zep.run/releases/0.9.0/zep_x86_64-macos_0.9.0.tar.xz"
    sha256 "d6f77bd81285eded86cfc080bfc535ad515ba14b08acb1668bd5d0aea6f32e74"
  end

  on_linux do
    url "https://zep.run/releases/0.9.0/zep_x86_64-linux_0.9.0.tar.xz"
    sha256 "37d09229bcec6efaa3b66d0143b27d305040b34ecbc51089169fe0db6919d676"
  end

  def install
    bin.install "zep" => "zep"
  end

    def post_install
		ohai "--- ZEP CONFIG REQUIRED ---"
		puts " ==> Run 'zep setup' to configure zep"
		puts " ==> Then run: zep zep install 0.9.0"
	end

  test do
    system "#{bin}/zep", "version"
  end
end
