# frozen_string_literal: true

RSpec.describe OpenUSD::ParseError do
  it "includes available source location in its message" do
    error = described_class.new("unexpected token", file: "scene.usda", line: 3, column: 8)

    expect(error.message).to eq("scene.usda:3:8: unexpected token")
    expect(error.file).to eq("scene.usda")
  end

  it "supports messages without a source location" do
    expect(described_class.new("bad input").message).to eq("bad input")
  end
end
