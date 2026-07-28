# frozen_string_literal: true

module OpenUSD
  # An authored prim specification in a Layer.
  class PrimSpec
    # Valid authored specifier values.
    SPECIFIERS = %i[def over class].freeze

    attr_reader :name, :children, :properties, :metadata, :references, :variant_sets, :specifier
    attr_accessor :type_name, :parent

    def initialize(name, type_name: nil, specifier: :def, metadata: {}, references: [], variant_sets: {})
      @name = validate_name(name)
      @type_name = type_name&.to_s
      self.specifier = specifier
      @metadata = metadata.dup
      @references = references.map { |reference| normalize_reference(reference) }
      @variant_sets = variant_sets.dup
      @children = []
      @child_index = {}
      @properties = []
      @property_index = {}
      @parent = nil
    end

    def specifier=(value)
      normalized = value.to_sym
      raise OpenUSD::TypeError, "invalid specifier: #{value.inspect}" unless SPECIFIERS.include?(normalized)

      @specifier = normalized
    end

    # Absolute path within the containing layer.
    def path
      return Path.parse("/#{name}") unless parent

      parent.path.child(name)
    end

    def add_child(child)
      raise OpenUSD::TypeError, "child must be a PrimSpec" unless child.is_a?(PrimSpec)
      raise PathError, "duplicate child prim: #{child.name}" if @child_index.key?(child.name)

      child.parent = self
      children << child
      @child_index[child.name] = child
      child
    end

    # Remove a direct child by name.
    # @return [PrimSpec, nil]
    def remove_child(name)
      child = child_named(name)
      return unless child

      children.delete(child)
      @child_index.delete(name.to_s)
      child.parent = nil
      child
    end

    # @return [PrimSpec, nil] direct child by name
    def child_named(name)
      @child_index[name.to_s]
    end

    def add_property(property)
      valid = property.is_a?(AttributeSpec) || property.is_a?(RelationshipSpec)
      raise OpenUSD::TypeError, "property must be an AttributeSpec or RelationshipSpec" unless valid
      raise PathError, "duplicate property: #{property.name}" if @property_index.key?(property.name)

      properties << property
      @property_index[property.name] = property
      property
    end

    # @return [AttributeSpec, RelationshipSpec, nil] authored property by name
    def property_named(name)
      @property_index[name.to_s]
    end

    # Remove an authored property by name.
    # @return [AttributeSpec, RelationshipSpec, nil]
    def remove_property(name)
      property = property_named(name)
      properties.delete(property)
      @property_index.delete(name.to_s)
      property
    end

    # Add a reference composition arc.
    # @return [Reference]
    def add_reference(asset_path, prim_path = nil)
      reference = Reference.new(asset_path, prim_path)
      references << reference
      reference
    end

    # Traverse authored descendants depth-first.
    # @return [Enumerator, nil]
    def each_descendant(&block)
      return enum_for(__method__) unless block

      children.each do |child|
        yield child
        child.each_descendant(&block)
      end
    end

    # @return [Hash] semantic representation used for equality
    def to_h
      {
        name: name, type_name: type_name, specifier: specifier,
        metadata: metadata, references: references, variant_sets: variant_sets_to_h,
        properties: semantic_properties(properties), children: children.map(&:to_h)
      }
    end

    private

    def validate_name(value)
      name = String(value)
      return name.dup.freeze if Path::PRIM_NAME.match?(name)

      raise PathError, "invalid prim name: #{name.inspect}"
    end

    def normalize_reference(value)
      return value if value.is_a?(Reference)
      return Reference.new(*value) if value.is_a?(Array)

      Reference.new(value)
    end

    def variant_sets_to_h
      variant_sets.transform_values do |choices|
        choices.transform_values do |variant|
          next variant unless variant.respond_to?(:properties)

          { properties: semantic_properties(variant.properties), children: variant.children.map(&:to_h) }
        end
      end
    end

    def semantic_properties(values)
      values.sort_by(&:name).map(&:to_h)
    end
  end
end
