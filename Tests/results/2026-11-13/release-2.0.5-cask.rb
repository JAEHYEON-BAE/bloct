cask "bloct" do
  version "2.0.5"
  sha256 "76d41d9ff36fcc1e9332c2e661b6af7fd0b22f0b2f353aadad4a6182ab3639b8"

  url "https://github.com/JAEHYEON-BAE/bloct/releases/download/v#{version}/Bloct.zip"
  name "Bloct"
  desc "Native macOS markdown viewer and editor"
  homepage "https://github.com/JAEHYEON-BAE/bloct"

  app "Bloct.app"
end
