# frozen_string_literal: true

module OpenUSD
  # Hash-compatible composed metadata that authors mutations through a callback.
  class MetadataView < Hash
    def initialize(values, writer:)
      super()
      values.each { |key, value| store(key.to_s, value) }
      @writer = writer
    end

    def []=(key, value)
      normalized = key.to_s
      @writer.call(:set, normalized, value)
      store(normalized, value)
    end

    def delete(key)
      normalized = key.to_s
      @writer.call(:delete, normalized, nil)
      super(normalized)
    end
  end
end
