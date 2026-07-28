# frozen_string_literal: true

module OpenUSD
  # Registry and validation for built-in USD value types.
  module Types
    # Integer ranges enforced when authoring.
    INTEGER_RANGES = {
      "int" => (-(2**31)...(2**31)),
      "uint" => (0...(2**32)),
      "int64" => (-(2**63)...(2**63)),
      "uint64" => (0...(2**64))
    }.freeze
    # Floating-point scalar type names.
    FLOAT_TYPES = %w[half float double].freeze
    # Vector and quaternion type names mapped to component counts.
    VECTOR_TYPES = {
      "float2" => 2, "float3" => 3, "float4" => 4,
      "double2" => 2, "double3" => 3, "double4" => 4,
      "half2" => 2, "half3" => 3, "half4" => 4,
      "int2" => 2, "int3" => 3, "int4" => 4,
      "point3f" => 3, "normal3f" => 3, "color3f" => 3,
      "color4f" => 4, "texCoord2f" => 2, "texCoord3f" => 3,
      "quatf" => 4, "quatd" => 4, "quath" => 4
    }.freeze
    # Matrix type names mapped to dimensions.
    MATRIX_TYPES = { "matrix2d" => 2, "matrix3d" => 3, "matrix4d" => 4 }.freeze
    # Built-in scalar type names.
    SCALAR_TYPES = %w[bool int uint int64 uint64 half float double string token asset].freeze
    # Internal dispatch table for scalar normalization.
    SIMPLE_COERCERS = {
      "bool" => :coerce_bool,
      "half" => :coerce_float,
      "float" => :coerce_float,
      "double" => :coerce_float,
      "string" => :coerce_string,
      "token" => :coerce_token,
      "asset" => :coerce_asset
    }.freeze

    module_function

    # Whether the registry recognizes a type name.
    def known?(type_name)
      name = base_type(type_name)
      SCALAR_TYPES.include?(name) || VECTOR_TYPES.key?(name) || MATRIX_TYPES.key?(name)
    end

    # Whether the type is an array type.
    def array?(type_name)
      String(type_name).end_with?("[]")
    end

    # Remove the array suffix from a type name.
    def base_type(type_name)
      String(type_name).delete_suffix("[]")
    end

    # Validate and normalize a Ruby value for a USD type.
    # Unknown types are intentionally preserved for forward compatibility.
    def coerce(type_name, value)
      name = String(type_name)
      return coerce_array(base_type(name), value) if array?(name)
      return value unless known?(name)

      coerce_scalar(name, value)
    rescue OpenUSD::TypeError
      raise
    rescue StandardError
      invalid!(name, value)
    end

    # Validate a Ruby value and return its normalized representation.
    def validate!(type_name, value)
      coerce(type_name, value)
    end

    def coerce_array(type_name, value)
      invalid!("#{type_name}[]", value) unless value.is_a?(Array)

      value.map { |element| coerce_scalar(type_name, element) }.freeze
    end
    private_class_method :coerce_array

    def coerce_scalar(type_name, value)
      coercer = SIMPLE_COERCERS[type_name]
      return send(coercer, value) if coercer
      return coerce_integer(type_name, value) if INTEGER_RANGES.key?(type_name)
      return coerce_vector(type_name, value) if VECTOR_TYPES.key?(type_name)
      return coerce_matrix(type_name, value) if MATRIX_TYPES.key?(type_name)
      return value unless known?(type_name)

      invalid!(type_name, value)
    end
    private_class_method :coerce_scalar

    def coerce_bool(value)
      return value if [true, false].include?(value)

      invalid!("bool", value)
    end
    private_class_method :coerce_bool

    def coerce_integer(type_name, value)
      range = INTEGER_RANGES.fetch(type_name)
      return value if value.is_a?(Integer) && range.cover?(value)

      invalid!(type_name, value)
    end
    private_class_method :coerce_integer

    def coerce_float(value)
      return value.to_f if value.is_a?(Numeric)

      invalid!("floating-point", value)
    end
    private_class_method :coerce_float

    def coerce_string(value)
      return value.dup.freeze if value.instance_of?(String)

      invalid!("string", value)
    end
    private_class_method :coerce_string

    def coerce_token(value)
      return Token.new(value) if value.is_a?(String)

      invalid!("token", value)
    end
    private_class_method :coerce_token

    def coerce_asset(value)
      return value if value.is_a?(AssetPath)
      return AssetPath.new(value) if value.is_a?(String)

      invalid!("asset", value)
    end
    private_class_method :coerce_asset

    def coerce_vector(type_name, value)
      size = VECTOR_TYPES.fetch(type_name)
      invalid!(type_name, value) unless value.is_a?(Array) && value.length == size

      scalar = type_name.start_with?("int") ? "int" : "double"
      value.map { |element| coerce_scalar(scalar, element) }.freeze
    end
    private_class_method :coerce_vector

    def coerce_matrix(type_name, value)
      size = MATRIX_TYPES.fetch(type_name)
      invalid!(type_name, value) unless matrix_shape?(value, size)

      value.map { |row| row.map { |element| coerce_float(element) }.freeze }.freeze
    end
    private_class_method :coerce_matrix

    def matrix_shape?(value, size)
      value.is_a?(Array) && value.length == size &&
        value.all? { |row| row.is_a?(Array) && row.length == size }
    end
    private_class_method :matrix_shape?

    def invalid!(type_name, value)
      raise OpenUSD::TypeError, "#{value.inspect} is not a valid #{type_name} value"
    end
    private_class_method :invalid!
  end
end
