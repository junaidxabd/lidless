# Homebrew cask for Lidless. After each release, update version + sha256
# (Scripts/release.sh prints both) and submit to homebrew/cask or serve
# from a personal tap.
cask "lidless" do
  version "1.0.0"
  sha256 "REPLACE_WITH_RELEASE_SHA256"

  url "https://github.com/junaidxabd/lidless/releases/download/v#{version}/Lidless-#{version}.zip"
  name "Lidless"
  desc "Keep a MacBook awake with the lid closed, with battery and thermal safety cutoffs"
  homepage "https://github.com/junaidxabd/lidless"

  depends_on macos: ">= :sequoia"

  app "Lidless.app"

  uninstall launchctl: "com.lidless.helper",
            quit:      "com.lidless.app"

  # /var/db/lidless is root-owned and removed by the in-app uninstall (or by
  # the helper itself); Homebrew's unprivileged zap cannot touch it.
  zap trash: [
        "~/Library/Application Support/Lidless",
        "~/Library/Group Containers/group.com.lidless.shared",
      ]

  caveats <<~EOS
    Lidless uses a privileged helper to override lid-close sleep. Prefer the
    in-app "Uninstall Lidless…" (Setup & Help) before `brew uninstall` — it
    restores all power-management state and removes the helper cleanly.
  EOS
end
