cask "bloct" do
  version "2.0.0"
  sha256 "dd2d1fb194fb13a5aa545fffbb8690e45e68c2ed1094c8060c42b07938df0e04"

  url "https://github.com/JAEHYEON-BAE/bloct/releases/download/v#{version}/Bloct.zip"
  name "Bloct"
  desc "Native macOS markdown viewer and editor"
  homepage "https://github.com/JAEHYEON-BAE/bloct"

  app "Bloct.app"
end
