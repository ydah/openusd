# frozen_string_literal: true

module OpenUSD
  # Immutable SdfPath-like value object for prim and property paths.
  class Path
    include Comparable

    # Reusable USD identifier fragment.
    IDENTIFIER = /[\p{L}_][\p{L}\p{N}_]*/u
    # Validation expression for prim names.
    PRIM_NAME = /\A#{IDENTIFIER}\z/u
    # Validation expression for namespaced property names.
    PROPERTY_NAME = /\A#{IDENTIFIER}(?::#{IDENTIFIER})*\z/u

    attr_reader :property_name

    class << self
      # Parse a path string.
      # @param value [String, Path]
      # @return [Path]
      # @raise [PathError] if the path is malformed
      def parse(value)
        return value if value.is_a?(self)

        new(String(value))
      rescue ArgumentError, TypeError
        raise PathError, "path must be a string or Path"
      end
    end

    def initialize(value)
      @value = value.dup.freeze
      @property_name = split_property
      validate!
      freeze
    end

    # Whether this path begins at the pseudo-root.
    def absolute?
      @value.start_with?("/")
    end

    # Whether this identifies a property rather than a prim.
    def property?
      !property_name.nil?
    end

    # Return the prim portion of this path.
    # @return [Path]
    def prim_path
      return self unless property?

      self.class.parse(@value.delete_suffix(".#{property_name}"))
    end

    # Return the namespace parent, or nil when no parent exists.
    # @return [Path, nil]
    def parent
      return prim_path if property?
      return nil if @value == "/"

      separator = @value.rindex("/")
      return nil unless separator
      return self.class.parse("/") if separator.zero?

      self.class.parse(@value[0...separator])
    end

    # Append a child prim name.
    # @param name [String]
    # @return [Path]
    def child(name)
      raise PathError, "a property path cannot have prim children" if property?

      child_name = String(name)
      raise PathError, "invalid prim name: #{child_name.inspect}" unless PRIM_NAME.match?(child_name)

      separator = @value == "/" ? "" : "/"
      self.class.parse("#{@value}#{separator}#{child_name}")
    rescue ArgumentError, TypeError
      raise PathError, "child name must be a string"
    end

    # Append a property name.
    # @param name [String]
    # @return [Path]
    def property(name)
      raise PathError, "a property path cannot have another property" if property?

      property = String(name)
      raise PathError, "invalid property name: #{property.inspect}" unless PROPERTY_NAME.match?(property)

      self.class.parse("#{@value}.#{property}")
    rescue ArgumentError, TypeError
      raise PathError, "property name must be a string"
    end

    # Compare paths by their canonical string form.
    def <=>(other)
      @value <=> self.class.parse(other).to_s
    rescue PathError
      nil
    end

    def eql?(other)
      other.is_a?(self.class) && @value == other.to_s
    end
    alias == eql?

    # @return [Integer] value hash compatible with {#eql?}
    def hash
      @value.hash
    end

    # @return [String] canonical path text
    def to_s
      @value
    end

    # @return [String] developer representation
    def inspect
      "#<#{self.class} #{@value.inspect}>"
    end

    private

    def split_property
      index = @value.index(".")
      return unless index

      @value[(index + 1)..]
    end

    def validate!
      raise PathError, "path cannot be empty" if @value.empty?
      return if @value == "/"

      validate_prim_path!
      return unless property?
      raise PathError, "property path requires a prim" if raw_prim_path.empty?
      raise PathError, "invalid property name: #{property_name.inspect}" unless PROPERTY_NAME.match?(property_name)
    end

    def validate_prim_path!
      prim = raw_prim_path
      raise PathError, "path cannot end with /" if prim.end_with?("/")
      raise PathError, "path cannot contain an empty component" if prim.include?("//")

      components = prim.delete_prefix("/").split("/")
      invalid = components.find { |part| !PRIM_NAME.match?(part) }
      raise PathError, "invalid prim name: #{invalid.inspect}" if invalid
    end

    def raw_prim_path
      property? ? @value[0...@value.index(".")] : @value
    end
  end
end
