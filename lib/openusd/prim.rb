# frozen_string_literal: true

module OpenUSD
  # Composed prim view on a Stage.
  class Prim
    attr_reader :stage, :path

    def initialize(stage, path)
      @stage = stage
      @path = Path.parse(path)
    end

    def name
      path.to_s.split("/").last
    end

    def type_name
      opinions.filter_map(&:type_name).find { |value| !value.empty? }
    end

    def type_name=(value)
      stage.set_prim_type(path, value)
    end

    def parent
      parent_path = path.parent
      return stage.pseudo_root if parent_path&.to_s == "/"
      return unless parent_path

      stage.prim_at(parent_path)
    end

    def children
      stage.child_paths(path).filter_map { |child_path| stage.prim_at(child_path) }
    end

    def attribute(name)
      properties = property_opinions(name)
      return unless properties.first.is_a?(AttributeSpec)

      Attribute.new(self, name)
    end

    def create_attribute(name, type_name)
      stage.author_attribute(path, name, type_name)
      Attribute.new(self, name)
    end

    def relationship(name)
      properties = property_opinions(name)
      return unless properties.first.is_a?(RelationshipSpec)

      Relationship.new(self, name)
    end

    def create_relationship(name)
      stage.author_relationship(path, name)
      Relationship.new(self, name)
    end

    def active?
      authored = opinions.find { |opinion| opinion.metadata.key?("active") }
      authored ? authored.metadata["active"] != false : true
    end

    def metadata
      values = opinions.reverse_each.with_object({}) { |opinion, result| result.merge!(opinion.metadata) }
      MetadataView.new(values, writer: method(:write_metadata))
    end

    def variant_sets
      opinions.reverse_each.with_object({}) do |opinion, result|
        result.merge!(opinion.variant_sets) if opinion.respond_to?(:variant_sets)
      end
    end

    def set_variant_selection(set_name, choice)
      stage.set_variant_selection(path, set_name, choice)
      self
    end

    def property_opinions(name)
      opinions.filter_map { |opinion| opinion.property_named(name) }
    end

    protected

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

    def path
      Path.parse("/")
    end

    def name
      ""
    end

    def type_name
      nil
    end

    def parent
      nil
    end

    def children
      stage.root_paths.filter_map { |root_path| stage.prim_at(root_path) }
    end
  end
end
