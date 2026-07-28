# frozen_string_literal: true

RSpec.describe OpenUSD do
  it "has a version number" do
    expect(described_class::VERSION).not_to be_nil
  end

  it "retains the generated namespace as a compatibility alias" do
    expect(Openusd).to equal(described_class)
  end
end
