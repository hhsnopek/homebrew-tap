class UtcClock < Formula
  desc "Menu bar clock that shows UTC and copies an RFC 3339 timestamp"
  homepage "https://github.com/hhsnopek/utc-clock"
  url "https://github.com/hhsnopek/utc-clock.git",
      tag:      "v1.0.0",
      revision: "deee357d19fb09dff5030c2342d3ca3553ddc2ed"
  license "MIT"
  head "https://github.com/hhsnopek/utc-clock.git", branch: "main"

  depends_on :macos

  def install
    system "make", "build"
    prefix.install "build/UTC Clock.app"
  end

  def caveats
    <<~EOS
      Start UTC Clock now and at every login:
        brew services start utc-clock
    EOS
  end

  # Quit in the menu means quit, so launchd starts it at login but never
  # restarts it.
  service do
    run [opt_prefix/"UTC Clock.app/Contents/MacOS/UTCClock"]
    keep_alive false
    process_type :interactive
  end

  test do
    assert_predicate prefix/"UTC Clock.app/Contents/MacOS/UTCClock", :executable?
  end
end
