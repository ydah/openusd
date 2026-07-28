# frozen_string_literal: true

RSpec.describe OpenUSD::AssetResolver do
  it "resolves paths relative to an anchor and search paths" do
    Dir.mktmpdir do |directory|
      asset = File.join(directory, "asset.usda")
      File.write(asset, "#usda 1.0\n")

      expect(described_class.new.resolve("asset.usda", anchor: File.join(directory, "root.usda"))).to eq(asset)
      expect(described_class.new(search_paths: [directory]).resolve("asset.usda")).to eq(asset)
    end
  end

  it "supports error, warning, and ignore policies" do
    expect { described_class.new.resolve("missing.usda") }.to raise_error(OpenUSD::CompositionError)
    result = :not_called
    expect { result = described_class.new(missing_assets: :warn).resolve("missing.usda") }
      .to output(/asset not found/).to_stderr
    expect(result).to be_nil
    expect(described_class.new(missing_assets: :ignore).resolve("missing.usda")).to be_nil
    expect { described_class.new(missing_assets: :other) }.to raise_error(ArgumentError)
  end
end
