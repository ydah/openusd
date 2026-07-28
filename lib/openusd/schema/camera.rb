# frozen_string_literal: true

module OpenUSD
  module Schema
    # Convenience API for common Camera attributes.
    class Camera < Base
      schema_type "Camera"

      def focal_length
        get("focalLength")
      end

      def focal_length=(value)
        set("focalLength", "float", value)
      end

      def clipping_range
        get("clippingRange")
      end

      def clipping_range=(value)
        set("clippingRange", "float2", value)
      end
    end
  end
end
