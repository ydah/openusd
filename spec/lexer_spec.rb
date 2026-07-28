# frozen_string_literal: true

RSpec.describe OpenUSD::Format::Usda::Lexer do
  def tokens(source)
    described_class.new(source, file: "test.usda").each_token.to_a
  end

  it "tokenizes the USDA value forms with locations" do
    source = <<~USDA
      #usda 1.0
      def Xform "World" {
        asset file = @texture.png@
        rel target = </Other>
        double value = -1.25e2
      }
    USDA

    result = tokens(source)

    expect(result.map(&:type)).to include(:magic, :identifier, :string, :asset, :path, :number)
    expect(result.find { |token| token.type == :number }.value).to eq(-125.0)
    expect(result.find { |token| token.value == "def" }.line).to eq(2)
  end

  it "removes all supported comment styles" do
    source = "#usda 1.0\n# line\n// line\n/* block\ncomment */\ndef Xform \"A\" {}"

    values = tokens(source).map(&:value).compact

    expect(values).to include("1.0", "def", "Xform", "A")
    expect(values).not_to include("line", "block")
  end

  it "decodes escaped and triple-quoted strings" do
    source = "#usda 1.0\n\"line\\nquote\\\"\" \"\"\"multi\nline\"\"\""
    strings = tokens(source).select { |token| token.type == :string }.map(&:value)

    expect(strings).to eq(["line\nquote\"", "multi\nline"])
  end

  it "reports lexical failures with line and column" do
    expect { tokens("#usda 1.0\n\"open") }
      .to raise_error(OpenUSD::ParseError, /test\.usda:2:1: unterminated string/)
    expect { tokens("#usda 1.0\n\\/") }.to raise_error(OpenUSD::ParseError, /2:1/)
  end
end
