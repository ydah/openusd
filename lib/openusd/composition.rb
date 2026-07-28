# frozen_string_literal: true

require "pathname"

module OpenUSD
  # Builds the v1 root/sublayer/reference composition index.
  class Composition
    # Internal prim-like opinion for a selected variant.
    VariantOpinion = Data.define(:properties, :metadata, :type_name) do
      # Find a property in the selected variant.
      # @api private
      def property_named(name)
        properties.find { |property| property.name == name.to_s }
      end
    end

    attr_reader :root_layer, :resolver, :layers, :layer_cache

    def initialize(root_layer, resolver:, layer_cache: {})
      @root_layer = root_layer
      @resolver = resolver
      @layer_cache = layer_cache
      @layer_cache[layer_key(root_layer)] = root_layer
      @layers = []
    end

    # Map absolute prim paths to opinions in strongest-to-weakest order.
    def build
      @layers = []
      compose_layer(root_layer, [])
    end

    private

    def compose_layer(layer, stack)
      key = layer_key(layer)
      cycle!(stack, key) if stack.include?(key)
      next_stack = stack + [key]
      layer_stack = collect_layer_stack(layer, next_stack)
      index = index_layer_stack(layer_stack)
      compose_references(index, next_stack)
      index
    end

    def collect_layer_stack(layer, stack)
      @layers << layer unless @layers.include?(layer)
      result = [layer]
      layer.sub_layer_paths.each do |authored_path|
        resolved = resolver.resolve(authored_path, anchor: layer.identifier)
        next unless resolved

        key = File.expand_path(resolved)
        cycle!(stack, key) if stack.include?(key)
        child = load_layer(resolved)
        result.concat(collect_layer_stack(child, stack + [key]))
      end
      result
    end

    def index_layer_stack(layer_stack)
      index = Hash.new { |hash, key| hash[key] = [] }
      layer_stack.each do |layer|
        layer.root_prims.each { |prim| index_prim(index, prim, "/#{prim.name}") }
      end
      index
    end

    def index_prim(index, prim, path)
      selected_variant_opinions(prim).each { |opinion| index[path] << opinion }
      index[path] << prim
      prim.children.each { |child| index_prim(index, child, "#{path}/#{child.name}") }
      index_variant_children(index, prim, path)
    end

    def selected_variant_opinions(prim)
      selections = prim.metadata["variants"]
      return [] unless selections.is_a?(Hash)

      selections.filter_map do |set_name, choice|
        variant = prim.variant_sets.dig(set_name.to_s, choice.to_s)
        VariantOpinion.new(variant.properties, {}, nil) if variant
      end
    end

    def index_variant_children(index, prim, path)
      selections = prim.metadata["variants"]
      return unless selections.is_a?(Hash)

      selections.each do |set_name, choice|
        variant = prim.variant_sets.dig(set_name.to_s, choice.to_s)
        next unless variant

        variant.children.each { |child| index_prim(index, child, "#{path}/#{child.name}") }
      end
    end

    def compose_references(index, stack)
      authored = index.to_a
      authored.each do |destination, opinions|
        opinions.grep(PrimSpec).each do |opinion|
          opinion.references.each { |reference| map_reference(index, destination, opinion, reference, stack) }
        end
      end
      index
    end

    def map_reference(index, destination, owner, reference, stack)
      resolved = resolver.resolve(reference.asset_path, anchor: layer_identifier(owner))
      return unless resolved

      referenced_layer = load_layer(resolved)
      source_index = compose_layer(referenced_layer, stack)
      source_root = reference.prim_path || referenced_layer.default_prim&.path
      raise CompositionError, "reference #{resolved} has no target or defaultPrim" unless source_root

      source_prefix = source_root.to_s
      source_index.each do |source_path, source_opinions|
        next unless source_path == source_prefix || source_path.start_with?("#{source_prefix}/")

        suffix = source_path.delete_prefix(source_prefix)
        index["#{destination}#{suffix}"].concat(source_opinions)
      end
    end

    def layer_identifier(owner)
      layers.find { |layer| layer.prim_at(owner.path) == owner }&.identifier || root_layer.identifier
    end

    def load_layer(identifier)
      key = identifier.match?(/\.usdz\[[^\]]+\]\z/i) ? identifier : File.expand_path(identifier)
      layer_cache[key] ||= Layer.open(identifier)
    end

    def layer_key(layer)
      identifier = layer.identifier
      return "anonymous:#{layer.object_id}" if identifier.nil? || identifier.start_with?("anonymous:")

      File.expand_path(identifier)
    end

    def cycle!(stack, key)
      chain = (stack + [key]).join(" -> ")
      raise CompositionError, "composition cycle detected: #{chain}"
    end
  end
end
