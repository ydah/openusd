# frozen_string_literal: true

module OpenUSD
  module Schema
    # Convenience API for common Camera attributes.
    class Camera < Base
      schema_type "Camera"

      # @return [Float, nil] focal length in tenths of a scene unit
      def focal_length
        get("focalLength")
      end

      # Author the focal length.
      def focal_length=(value)
        set("focalLength", "float", value)
      end

      # @return [Array<Float>, nil] near and far clipping distances
      def clipping_range
        get("clippingRange")
      end

      # Author near and far clipping distances.
      def clipping_range=(value)
        set("clippingRange", "float2", value)
      end
    end
  end
end
