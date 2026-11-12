cask "bloct" do
  version "2.0.2"
  sha256 "cd6c1fde61d465222d352b23c0d028a9fef1f11d0676ae33267342f4f9546d03"

  url "https://github.com/JAEHYEON-BAE/bloct/releases/download/v#{version}/Bloct.zip"
  name "Bloct"
  desc "Native macOS markdown viewer and editor"
  homepage "https://github.com/JAEHYEON-BAE/bloct"

  app "Bloct.app"
end
