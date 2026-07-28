# frozen_string_literal: true

module OpenUSD
  # Composed attribute view on a Stage.
  class Attribute
    attr_reader :prim, :name

    def initialize(prim, name)
      @prim = prim
      @name = name.to_s
    end

    def type_name
      opinions.first&.type_name
    end

    def get(time: nil)
      return default_value if time.nil?

      sampled_value(Float(time))
    rescue ArgumentError, ::TypeError
      raise OpenUSD::TypeError, "time must be numeric"
    end

    def set(value, time: nil)
      authored_spec.set(value, time: time)
      prim.stage.invalidate!
      value
    end

    def time_samples
      opinions.reverse_each.with_object({}) { |opinion, result| result.merge!(opinion.time_samples) }.sort.to_h
    end

    def connections
      opinions.find { |opinion| opinion.connections.any? }&.connections || []
    end

    def metadata
      values = opinions.reverse_each.with_object({}) { |opinion, result| result.merge!(opinion.metadata) }
      MetadataView.new(values, writer: method(:write_metadata))
    end

    private

    def opinions
      prim.property_opinions(name).grep(AttributeSpec)
    end

    def default_value
      opinions.find(&:default_authored?)&.default
    end

    def sampled_value(time)
      opinion = opinions.find { |candidate| candidate.time_samples.any? }
      return default_value unless opinion

      samples = opinion.time_samples
      return samples[time] if samples.key?(time)

      interpolate_samples(samples, time)
    end

    def interpolate_samples(samples, time)
      times = samples.keys
      return samples[times.first] if time <= times.first
      return samples[times.last] if time >= times.last

      upper = times.find { |sample_time| sample_time > time }
      lower = times[times.index(upper) - 1]
      interpolate(samples[lower], samples[upper], (time - lower) / (upper - lower))
    end

    def interpolate(left, right, alpha)
      return left + ((right - left) * alpha) if left.is_a?(Numeric) && right.is_a?(Numeric)
      if left.is_a?(Array) && right.is_a?(Array) && left.length == right.length
        return left.zip(right).map { |a, b| interpolate(a, b, alpha) }
      end

      left
    end

    def authored_spec
      prim.stage.author_attribute(prim.path, name, type_name)
    end

    def write_metadata(operation, key, value)
      authored = authored_spec.metadata
      operation == :set ? authored[key] = value : authored.delete(key)
      prim.stage.invalidate!
    end
  end
end
