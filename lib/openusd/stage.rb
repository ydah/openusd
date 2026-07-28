# frozen_string_literal: true

module OpenUSD
  # Composed, editable view of one root layer and its composition arcs.
  class Stage
    attr_reader :root_layer, :resolver, :pseudo_root, :edit_target

    class << self
      # Open a composed stage.
      # @return [Stage]
      def open(path, missing_assets: :error)
        expanded = File.expand_path(path)
        resolver = AssetResolver.new(missing_assets: missing_assets)
        new(Layer.open(expanded), resolver: resolver)
      end

      # Create an empty file-backed stage.
      # @return [Stage]
      def create(identifier)
        new(Layer.create(identifier))
      end

      # Create an anonymous in-memory stage.
      # @return [Stage]
      def create_in_memory
        new(Layer.create("anonymous:#{object_id}:#{Process.clock_gettime(Process::CLOCK_MONOTONIC)}"))
      end
    end

    def initialize(root_layer, resolver: AssetResolver.new)
      @root_layer = root_layer
      @resolver = resolver
      @edit_target = root_layer
      @pseudo_root = PseudoRoot.new(self)
      @composition = nil
      @index = nil
      @layer_cache = {}
    end

    def edit_target=(layer)
      raise OpenUSD::TypeError, "edit target must be a Layer" unless layer.is_a?(Layer)
      raise CompositionError, "edit target is not in this stage's layer stack" unless layer_stack.include?(layer)

      @edit_target = layer
    end

    # Find an active composed prim.
    # @return [Prim, PseudoRoot, nil]
    def prim_at(path)
      parsed = Path.parse(path)
      return pseudo_root if parsed.to_s == "/"
      return nil if parsed.property?
      return nil unless composed_index.key?(parsed.to_s)

      prim = Prim.new(self, parsed)
      prim.active? ? prim : nil
    end

    # @return [Prim, nil] composed default prim
    def default_prim
      name = root_layer.metadata["defaultPrim"]
      prim_at("/#{name}") if name
    end

    # Define a prim and any missing ancestors in the edit target.
    # @return [Prim]
    def define_prim(path, type_name = nil)
      parsed = validate_prim_path(path)
      spec = ensure_spec(edit_target, parsed)
      spec.specifier = :def
      spec.type_name = type_name.to_s if type_name
      invalidate!
      Prim.new(self, parsed)
    end

    # Remove or deactivate a prim in the edit target.
    # @return [Stage]
    def remove_prim(path)
      parsed = validate_prim_path(path)
      remove_spec(edit_target, parsed)
      invalidate!
      if composed_index.key?(parsed.to_s)
        blocker = ensure_spec(edit_target, parsed)
        blocker.specifier = :over
        blocker.metadata["active"] = false
      end
      invalidate!
      self
    end

    # Traverse active prims depth-first.
    # @return [Enumerator, Stage]
    def traverse
      return enum_for(__method__) unless block_given?

      walk = lambda do |prim|
        yield prim
        prim.children.each { |child| walk.call(child) }
      end
      pseudo_root.children.each { |prim| walk.call(prim) }
      self
    end

    # Save the root layer to its identifier.
    # @return [Stage]
    def save
      root_layer.save
      self
    end

    # Export the root layer by destination extension.
    # @return [Stage]
    def export(path)
      root_layer.export(path)
      self
    end

    # Author a variant choice for a prim.
    # @return [Stage]
    def set_variant_selection(path, set_name, choice)
      prim = prim_at(path)
      raise CompositionError, "prim not found: #{path}" unless prim

      choices = prim.variant_sets[set_name.to_s]
      raise CompositionError, "variant set not found: #{set_name}" unless choices
      raise CompositionError, "variant not found: #{choice}" unless choices.key?(choice.to_s)

      spec = ensure_spec(edit_target, Path.parse(path))
      spec.metadata["variants"] ||= {}
      spec.metadata["variants"][set_name.to_s] = choice.to_s
      invalidate!
      self
    end

    # @api private
    # @return [Array<PrimSpec>] strongest-to-weakest opinions
    def opinions_for(path)
      composed_index.fetch(Path.parse(path).to_s, [])
    end

    # @api private
    # @return [Array<Path>] direct composed child paths
    def child_paths(path)
      prefix = "#{Path.parse(path)}/"
      paths = composed_index.keys.select do |candidate|
        candidate.start_with?(prefix) && !candidate.delete_prefix(prefix).include?("/")
      end
      paths.sort.map { |candidate| Path.parse(candidate) }
    end

    # @api private
    # @return [Array<Path>] composed root paths
    def root_paths
      composed_index.keys.select { |path| path.count("/") == 1 }.sort.map { |path| Path.parse(path) }
    end

    # Find or author an attribute spec in the edit target.
    # @api private
    def author_attribute(path, name, type_name)
      spec = ensure_spec(edit_target, Path.parse(path))
      property = spec.property_named(name)
      validate_property_kind!(property, AttributeSpec, "#{name} is authored as a relationship")
      property ||= spec.add_property(AttributeSpec.new(name, type_name || "token"))
      property.type_name = type_name if type_name
      invalidate!
      property
    end

    # Find or author a relationship spec in the edit target.
    # @api private
    def author_relationship(path, name)
      spec = ensure_spec(edit_target, Path.parse(path))
      property = spec.property_named(name)
      validate_property_kind!(property, RelationshipSpec, "#{name} is authored as an attribute")
      property ||= spec.add_property(RelationshipSpec.new(name))
      invalidate!
      property
    end

    # Author a prim type in the edit target.
    # @api private
    def set_prim_type(path, type_name)
      spec = ensure_spec(edit_target, Path.parse(path))
      spec.type_name = type_name&.to_s
      invalidate!
      type_name
    end

    # Apply one metadata mutation to an edit-target prim spec.
    # @api private
    def author_prim_metadata(path, operation, key, value)
      metadata = ensure_spec(edit_target, Path.parse(path)).metadata
      operation == :set ? metadata[key] = value : metadata.delete(key)
      invalidate!
    end

    # @return [Array<Layer>] layers participating in composition
    def layer_stack
      composed_index
      @composition.layers
    end

    # @api private
    # Invalidate the cached composition index after an edit.
    def invalidate!
      @index = nil
      @composition = nil
      self
    end

    private

    def composed_index
      return @index if @index

      @composition = Composition.new(root_layer, resolver: resolver, layer_cache: @layer_cache)
      @index = @composition.build
    end

    def validate_prim_path(path)
      parsed = Path.parse(path)
      invalid = !parsed.absolute? || parsed.property? || parsed.to_s == "/"
      raise PathError, "absolute non-root prim path required" if invalid

      parsed
    end

    def ensure_spec(layer, path)
      existing = layer.prim_at(path)
      return existing if existing

      names = path.to_s.delete_prefix("/").split("/")
      parent = nil
      names.each do |name|
        child = parent ? parent.child_named(name) : layer.root_prim_named(name)
        unless child
          child = PrimSpec.new(name, specifier: :over)
          parent ? parent.add_child(child) : layer.add_root_prim(child)
        end
        parent = child
      end
      parent
    end

    def remove_spec(layer, path)
      spec = layer.prim_at(path)
      return unless spec

      if spec.parent
        spec.parent.remove_child(spec.name)
      else
        layer.remove_root_prim(spec.name)
      end
    end

    def validate_property_kind!(property, expected_class, message)
      return if property.nil? || property.is_a?(expected_class)

      raise OpenUSD::TypeError, message
    end
  end
end
