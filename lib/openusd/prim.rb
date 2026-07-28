# frozen_string_literal: true

module OpenUSD
  # Composed prim view on a Stage.
  class Prim
    attr_reader :stage, :path

    def initialize(stage, path)
      @stage = stage
      @path = Path.parse(path)
    end

    # @return [String] final path component
    def name
      path.to_s.split("/").last
    end

    # @return [String, nil] strongest authored type name
    def type_name
      opinions.filter_map(&:type_name).find { |value| !value.empty? }
    end

    # Author a type name in the edit target.
    def type_name=(value)
      stage.set_prim_type(path, value)
    end

    # @return [Prim, PseudoRoot, nil] composed namespace parent
    def parent
      parent_path = path.parent
      return stage.pseudo_root if parent_path&.to_s == "/"
      return unless parent_path

      stage.prim_at(parent_path)
    end

    # @return [Array<Prim>] active direct children
    def children
      stage.child_paths(path).filter_map { |child_path| stage.prim_at(child_path) }
    end

    # @return [Attribute, nil] composed attribute by name
    def attribute(name)
      properties = property_opinions(name)
      return unless properties.first.is_a?(AttributeSpec)

      Attribute.new(self, name)
    end

    # Create or return an attribute in the edit target.
    # @return [Attribute]
    def create_attribute(name, type_name)
      stage.author_attribute(path, name, type_name)
      Attribute.new(self, name)
    end

    # @return [Relationship, nil] composed relationship by name
    def relationship(name)
      properties = property_opinions(name)
      return unless properties.first.is_a?(RelationshipSpec)

      Relationship.new(self, name)
    end

    # Create or return a relationship in the edit target.
    # @return [Relationship]
    def create_relationship(name)
      stage.author_relationship(path, name)
      Relationship.new(self, name)
    end

    def active?
      authored = opinions.find { |opinion| opinion.metadata.key?("active") }
      authored ? authored.metadata["active"] != false : true
    end

    # @return [MetadataView] composed, writable metadata
    def metadata
      values = opinions.reverse_each.with_object({}) { |opinion, result| result.merge!(opinion.metadata) }
      MetadataView.new(values, writer: method(:write_metadata))
    end

    # @return [Hash] composed variant-set definitions
    def variant_sets
      opinions.reverse_each.with_object({}) do |opinion, result|
        result.merge!(opinion.variant_sets) if opinion.respond_to?(:variant_sets)
      end
    end

    # Author a variant selection.
    # @return [Prim]
    def set_variant_selection(set_name, choice)
      stage.set_variant_selection(path, set_name, choice)
      self
    end

    # @api private
    # @return [Array<AttributeSpec, RelationshipSpec>]
    def property_opinions(name)
      opinions.filter_map { |opinion| opinion.property_named(name) }
    end

    protected

    # Return all composed opinions for this prim.
    # @api private
    def opinions
      stage.opinions_for(path)
    end

    private

    def write_metadata(operation, key, value)
      stage.author_prim_metadata(path, operation, key, value)
    end
  end

  # Synthetic root for a Stage's root prims.
  class PseudoRoot
    attr_reader :stage

    def initialize(stage)
      @stage = stage
    end

    # @return [Path] pseudo-root path
    def path
      Path.parse("/")
    end

    # @return [String] empty pseudo-root name
    def name
      ""
    end

    # @return [nil]
    def type_name
      nil
    end

    # @return [nil]
    def parent
      nil
    end

    # @return [Array<Prim>] active root prims
    def children
      stage.root_paths.filter_map { |root_path| stage.prim_at(root_path) }
    end
  end
end
