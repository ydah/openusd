# frozen_string_literal: true

module OpenUSD
  # Composed relationship view on a Stage.
  class Relationship
    attr_reader :prim, :name

    def initialize(prim, name)
      @prim = prim
      @name = name.to_s
    end

    # @return [Array<Path>] strongest authored targets
    def targets
      opinions.find { |opinion| opinion.targets.any? }&.targets || []
    end

    # Add one target in the edit target.
    # @return [Relationship]
    def add_target(path)
      authored_spec.add_target(path)
      prim.stage.invalidate!
      self
    end

    # Replace targets in the edit target.
    # @return [Relationship]
    def set_targets(paths)
      authored_spec.targets = paths
      prim.stage.invalidate!
      self
    end

    # @return [MetadataView] composed, writable metadata
    def metadata
      values = opinions.reverse_each.with_object({}) { |opinion, result| result.merge!(opinion.metadata) }
      MetadataView.new(values, writer: method(:write_metadata))
    end

    private

    def opinions
      prim.property_opinions(name).grep(RelationshipSpec)
    end

    def authored_spec
      prim.stage.author_relationship(prim.path, name)
    end

    def write_metadata(operation, key, value)
      authored = authored_spec.metadata
      operation == :set ? authored[key] = value : authored.delete(key)
      prim.stage.invalidate!
    end
  end
end
