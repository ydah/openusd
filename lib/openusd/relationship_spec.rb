# frozen_string_literal: true

module OpenUSD
  # An authored relationship in a Layer.
  class RelationshipSpec
    # Sentinel distinguishing no target opinion from an authored empty list.
    UNAUTHORED = Object.new.freeze

    attr_reader :name, :targets, :metadata
    attr_accessor :custom

    def initialize(name, targets: UNAUTHORED, custom: false, metadata: {})
      @name = validate_name(name)
      @custom = custom == true
      @metadata = metadata.dup
      @targets = []
      @targets_authored = false
      self.targets = targets unless targets.equal?(UNAUTHORED)
    end

    def targets=(paths)
      @targets = Array(paths).map { |path| Path.parse(path) }
      @targets_authored = true
    end

    # Whether targets, including an empty list, are authored.
    def targets_authored?
      @targets_authored
    end

    # Add a target unless it is already present.
    # @return [Path]
    def add_target(path)
      target = Path.parse(path)
      @targets << target unless @targets.include?(target)
      @targets_authored = true
      target
    end

    # @return [Hash] semantic representation used for equality
    def to_h
      {
        name: name, targets: targets, targets_authored: targets_authored?,
        custom: custom, metadata: metadata
      }
    end

    private

    def validate_name(value)
      name = String(value)
      return name.dup.freeze if Path::PROPERTY_NAME.match?(name)

      raise PathError, "invalid relationship name: #{name.inspect}"
    end
  end
end
