# frozen_string_literal: true

module OpenUSD
  # A USD token. It remains distinct from a string for serialization.
  class Token < String
    def initialize(value)
      super(String(value))
      freeze
    end
  end

  # An authored USD asset path, optionally paired with its resolved path.
  class AssetPath
    attr_reader :path, :resolved_path

    def initialize(path, resolved_path: nil)
      @path = String(path).dup.freeze
      @resolved_path = resolved_path.nil? ? nil : resolved_path.to_s.dup.freeze
      freeze
    end

    def eql?(other)
      other.is_a?(self.class) && path == other.path && resolved_path == other.resolved_path
    end
    alias == eql?

    # @return [Integer] value hash
    def hash
      [path, resolved_path].hash
    end

    # @return [String] authored, unresolved asset path
    def to_s
      path
    end
  end

  # Preserves a USDA list-edit operator together with its value.
  class ListOp
    attr_reader :operation, :value

    def initialize(operation, value)
      @operation = operation.to_sym
      @value = value
      freeze
    end

    # Compare the list operation and value.
    def ==(other)
      other.is_a?(self.class) && operation == other.operation && value == other.value
    end
  end

  # A layer reference and optional target prim.
  class Reference
    attr_reader :asset_path, :prim_path

    class << self
      # Build an internal reference to a prim in the same layer stack.
      # @return [Reference]
      def internal(prim_path)
        new(nil, prim_path)
      end
    end

    def initialize(asset_path = nil, prim_path = nil)
      if asset_path.is_a?(Path) && prim_path.nil?
        prim_path = asset_path
        asset_path = nil
      end
      raise OpenUSD::TypeError, "a reference requires an asset path or prim path" if asset_path.nil? && prim_path.nil?

      @asset_path = normalize_asset_path(asset_path)
      @prim_path = prim_path.nil? ? nil : Path.parse(prim_path)
      freeze
    end

    # Whether this reference targets the current layer stack.
    def internal?
      asset_path.nil?
    end

    # Compare asset and target paths.
    def ==(other)
      other.is_a?(self.class) && asset_path == other.asset_path && prim_path == other.prim_path
    end

    private

    def normalize_asset_path(value)
      return if value.nil?
      return value if value.is_a?(AssetPath)

      AssetPath.new(value)
    end
  end

  # Authored contents of one variant choice.
  Variant = Data.define(:properties, :children)
end
