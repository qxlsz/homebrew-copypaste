# Official tap: brew install qxlsz/copypaste/copypaste
class Copypaste < Formula
  desc "Pastebin CLI and self-hostable server"
  homepage "https://www.copypaste.fyi"
  license "MIT"
  head "https://github.com/qxlsz/copypaste.fyi.git", branch: "main"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
  end

  def caveats
    <<~EOS
      Public site:  copypaste send --host https://www.copypaste.fyi "notes"
      Local server: copypaste serve
                    brew services start copypaste

      Closed instance: set COPYPASTE_REQUIRE_WRITE_AUTH=true and
      COPYPASTE_AUTH_TOKEN in the environment. Tokens never go on argv.
    EOS
  end

  service do
    run [opt_bin/"copypaste", "serve"]
    keep_alive true
    working_dir var
    log_path var/"log/copypaste.log"
    error_log_path var/"log/copypaste.log"
    environment_variables ROCKET_ADDRESS: "127.0.0.1", COPYPASTE_FORCE_MEMORY: "true"
  end

  test do
    help = shell_output("#{bin/"copypaste"} --help")
    assert_match "serve", help
    assert_match "send", help

    config = testpath/"copypaste.toml"
    assert_match "Config written",
                 shell_output("#{bin/"copypaste"} config init --path #{config}")
    assert_path_exists config
    assert_match "[server]", config.read
    assert_match "require_write_auth", config.read

    https_error = shell_output("#{bin/"copypaste"} send hi --host http://example.com 2>&1", 1)
    assert_match "must use HTTPS", https_error
  end
end
