class Kujto < Formula
  desc "Local memory layer for AI coding agents"
  homepage "https://kujto.peterdsp.dev"
  url "https://github.com/peterdsp/kujto/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "REPLACE_ME_WITH_ACTUAL_SHA_256_OF_THE_RELEASE_TARBALL"
  license "MIT"
  head "https://github.com/peterdsp/kujto.git", branch: "main"

  depends_on xcode: ["15.0", :build]

  def install
    system "swift", "build",
           "--configuration", "release",
           "--disable-sandbox"
    bin.install ".build/release/kujto"

    # Copy AGENTS.md and the memory tree into a shared location so `kujto`
    # can find its root via KujtoRoot.locate.
    (share/"kujto").install "AGENTS.md", "memory"
  end

  def caveats
    <<~EOS
      Kujto's memory framework was installed to:
        #{share}/kujto

      Set KUJTO_ROOT to point at that path so wire/agents/rules commands
      can find AGENTS.md:

        echo 'export KUJTO_ROOT="#{share}/kujto"' >> ~/.zshrc

      Then run `kujto wire` from any repo to symlink CLAUDE.md, CODEX.md,
      GEMINI.md, AGENTS.md, .cursorrules, and .github/copilot-instructions.md.
    EOS
  end

  test do
    assert_match "kujto", shell_output("#{bin}/kujto --version")
  end
end
