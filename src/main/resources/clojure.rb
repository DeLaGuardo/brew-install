class Clojure < Formula
  desc "The Clojure Programming Language"
  homepage "https://clojure.org"
  url "https://download.clojure.org/install/clojure-tools-${project.version}.tar.gz"
  sha256 "SHA"

  bottle :unneeded

  depends_on :java => "1.8+"
  depends_on "rlwrap"
  depends_on "coreutils" => :build

  def install
    system "./install.sh", "-p", prefix, "--local"
  end

  test do
    ENV["TERM"] = "xterm"
    system("#{bin}/clj -e nil")
    %w[clojure clj].each do |clj|
      assert_equal "2", shell_output("#{bin}/#{clj} -e \"(+ 1 1)\"").strip
    end
  end
end
