# frozen_string_literal: true

module OpenUSD
  # An authored relationship in a Layer.
  class RelationshipSpec
    attr_reader :name, :targets, :metadata
    attr_accessor :custom

    def initialize(name, targets: [], custom: false, metadata: {})
      @name = validate_name(name)
      @custom = custom == true
      @metadata = metadata.dup
      self.targets = targets
    end

    def targets=(paths)
      @targets = Array(paths).map { |path| Path.parse(path) }
    end

    def add_target(path)
      target = Path.parse(path)
      @targets << target unless @targets.include?(target)
      target
    end

    def to_h
      { name: name, targets: targets, custom: custom, metadata: metadata }
    end

    private

    def validate_name(value)
      name = String(value)
      return name.dup.freeze if Path::PROPERTY_NAME.match?(name)

      raise PathError, "invalid relationship name: #{name.inspect}"
    end
  end
end
