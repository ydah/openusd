# frozen_string_literal: true

module OpenUSD
  # A single authored USD layer.
  class Layer
    attr_reader :identifier, :root_prims, :metadata

    class << self
      # Create an empty layer.
      # @return [Layer]
      def create(identifier)
        new(identifier)
      end

      # Open a USDA, USD, or USDZ layer.
      # @return [Layer]
      def open(path)
        if path.to_s.match?(/\.usdz\[[^\]]+\]\z/i)
          require_relative "format/usdz/reader"
          return Format::Usdz::Reader.read_uri(path.to_s)
        end

        expanded = File.expand_path(path)
        Format::Registry.reader_for(expanded).read(expanded)
      rescue Errno::ENOENT
        raise CompositionError, "layer not found: #{expanded}"
      end
    end

    def initialize(identifier = nil, metadata: {}, root_prims: [])
      @identifier = identifier&.to_s
      @metadata = metadata.dup
      @root_prims = []
      root_prims.each { |prim| add_root_prim(prim) }
    end

    def identifier=(value)
      @identifier = value&.to_s
    end

    def add_root_prim(prim)
      raise OpenUSD::TypeError, "root prim must be a PrimSpec" unless prim.is_a?(PrimSpec)
      raise PathError, "duplicate root prim: #{prim.name}" if root_prim_named(prim.name)

      prim.parent = nil
      root_prims << prim
      prim
    end

    # Remove and return a root prim by name.
    # @return [PrimSpec, nil]
    def remove_root_prim(name)
      prim = root_prim_named(name)
      root_prims.delete(prim)
      prim
    end

    # @return [PrimSpec, nil] root prim with the requested name
    def root_prim_named(name)
      root_prims.find { |prim| prim.name == name.to_s }
    end

    def prim_at(path)
      parsed = Path.parse(path)
      raise PathError, "prim path required" if parsed.property?
      return nil unless parsed.absolute?
      return nil if parsed.to_s == "/"

      names = parsed.to_s.delete_prefix("/").split("/")
      names.drop(1).reduce(root_prim_named(names.first)) { |prim, name| prim&.child_named(name) }
    end

    # Traverse authored specs depth-first.
    # @return [Enumerator, Layer]
    def each_prim(&block)
      return enum_for(__method__) unless block

      root_prims.each do |prim|
        yield prim
        prim.each_descendant(&block)
      end
    end

    # @return [Array<String>] authored sublayer asset paths
    def sub_layer_paths
      value = metadata["subLayers"]
      value = value.value if value.is_a?(ListOp)
      Array(value).map { |path| path.is_a?(AssetPath) ? path.path : path.to_s }
    end

    # @return [PrimSpec, nil] authored default prim
    def default_prim
      name = metadata["defaultPrim"]
      name = name.to_s if name
      root_prim_named(name)
    end

    def save
      raise Error, "in-memory layer has no identifier" unless identifier

      export(identifier)
    end

    # Export using the format selected by the destination extension.
    # @return [Layer]
    def export(path)
      Format::Registry.writer_for(path).write(self, path)
      self
    end

    # @return [String] deterministic USDA representation
    def to_usda
      require_relative "format/usda/writer"
      Format::Usda::Writer.new.write_to_string(self)
    end

    # Compare authored semantic content, ignoring identifiers.
    def ==(other)
      other.is_a?(self.class) && metadata == other.metadata &&
        root_prims.map(&:to_h) == other.root_prims.map(&:to_h)
    end
  end
end
