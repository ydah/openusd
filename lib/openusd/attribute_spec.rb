# frozen_string_literal: true

module OpenUSD
  # An authored attribute in a Layer.
  class AttributeSpec
    UNAUTHORED = Object.new.freeze
    VARIABILITIES = %i[varying uniform].freeze

    attr_reader :name, :type_name, :time_samples, :connections, :metadata, :variability, :default
    attr_accessor :custom

    def initialize(name, type_name, default: UNAUTHORED, variability: :varying, custom: false, metadata: {})
      @name = validate_name(name)
      @type_name = String(type_name).dup.freeze
      self.variability = variability
      @custom = custom == true
      @metadata = metadata.dup
      @connections = []
      @time_samples = {}
      @default_authored = false
      set(default) unless default.equal?(UNAUTHORED)
    end

    def type_name=(value)
      normalized = String(value).dup.freeze
      Types.validate!(normalized, @default) if default_authored? && !@default.nil?
      @time_samples.each_value { |sample| Types.validate!(normalized, sample) unless sample.nil? }
      @type_name = normalized
    end

    def variability=(value)
      normalized = value.to_sym
      raise OpenUSD::TypeError, "invalid variability: #{value.inspect}" unless VARIABILITIES.include?(normalized)

      @variability = normalized
    end

    # Whether a default opinion, including a value block, is authored.
    def default_authored?
      @default_authored
    end

    # Set a default or time-sampled value.
    def set(value, time: nil)
      normalized = value.nil? ? nil : Types.coerce(type_name, value)
      return set_time_sample(time, normalized) unless time.nil?

      @default = normalized
      @default_authored = true
      normalized
    end

    # Remove the default opinion.
    def clear_default
      @default = nil
      @default_authored = false
      self
    end

    # Replace time samples, normalizing their keys and values.
    def time_samples=(samples)
      @time_samples = samples.each_with_object({}) do |(time, value), result|
        result[Float(time)] = value.nil? ? nil : Types.coerce(type_name, value)
      end.sort.to_h
    rescue ArgumentError, ::TypeError
      raise OpenUSD::TypeError, "time sample keys must be numeric"
    end

    # Replace all connection paths.
    def connections=(paths)
      @connections = Array(paths).map { |path| Path.parse(path) }
    end

    def to_h
      {
        name: name, type_name: type_name, default: default,
        default_authored: default_authored?, time_samples: time_samples,
        variability: variability, custom: custom, connections: connections,
        metadata: metadata
      }
    end

    private

    def validate_name(value)
      name = String(value)
      return name.dup.freeze if Path::PROPERTY_NAME.match?(name)

      raise PathError, "invalid attribute name: #{name.inspect}"
    end

    def set_time_sample(time, value)
      @time_samples[Float(time)] = value
      @time_samples = @time_samples.sort.to_h
      value
    rescue ArgumentError, ::TypeError
      raise OpenUSD::TypeError, "time must be numeric"
    end
  end
end
