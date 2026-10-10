class Tailtray < Formula
  desc "Tailscale status and exit node control in the menu bar"
  homepage "https://github.com/hhsnopek/tailtray"
  license "MIT"
  head "https://github.com/hhsnopek/tailtray.git", branch: "main"

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(ldflags: "-s -w")
  end

  def caveats
    <<~EOS
      Start tailtray now and at every login:
        brew services start tailtray
    EOS
  end

  # Quit in the menu means quit, so launchd starts it at login but never
  # restarts it.
  service do
    run [opt_bin/"tailtray"]
    keep_alive false
    process_type :interactive
  end

  test do
    assert_match "-socket", shell_output("#{bin}/tailtray -h 2>&1")
  end
end
