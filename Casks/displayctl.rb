# Homebrew cask for DisplayCtl: installs the menu bar app and the CLI.
#
# A cask, not a formula, because Homebrew refuses to install a formula from
# source when Xcode is older than the running macOS, and casks ship prebuilt
# artifacts. It is also how menu bar apps are normally distributed.
#
# To publish:
#   1. push this repo to GitHub
#   2. ./make-app.sh
#      ditto -c -k --sequesterRsrc --keepParent DisplayCtl.app DisplayCtl-0.1.0.zip
#      shasum -a 256 DisplayCtl-0.1.0.zip
#   3. attach the zip to the v0.1.0 release and paste the checksum here
#   4. put this file in the Casks directory of a tap repo named homebrew-tap
#
# Users then run:
#   brew install --cask magicilabs/tap/displayctl
cask "displayctl" do
  version "0.1.5"
  sha256 "24fb7074a9006eeb1d4f1fb3069f151074cc72b26b9f5492e2179404e901fa6d"

  url "https://github.com/magicilabs/displayctl/releases/download/v#{version}/DisplayCtl-#{version}.zip"
  name "DisplayCtl"
  desc "Menu bar app and CLI to connect, disconnect and control macOS displays"
  homepage "https://github.com/magicilabs/displayctl"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "DisplayCtl.app"
  # The app bundles the same binary the CLI uses; expose it under its own name.
  binary "#{appdir}/DisplayCtl.app/Contents/MacOS/displayctl-bin", target: "displayctl"

  uninstall quit: "local.displayctl"

  zap trash: [
    "~/Library/Logs/displayctl.log",
    "~/Library/Application Support/displayctl",
  ]

  caveats <<~EOS
    To start it at login, tick Start at Login in its menu.
  EOS
end
