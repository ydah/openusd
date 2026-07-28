# frozen_string_literal: true

module OpenUSD
  module Schema
    # Convenience API for Xform prims and common transform operations.
    class Xform < Base
      schema_type "Xform"

      # @return [Array<Float>, nil] translation operation
      def translate
        get("xformOp:translate")
      end

      # Author the translation operation.
      def translate=(value)
        set_operation("xformOp:translate", "double3", value)
      end

      # @return [Array<Float>, nil] XYZ rotation operation
      def rotate_xyz
        get("xformOp:rotateXYZ")
      end

      # Author the XYZ rotation operation.
      def rotate_xyz=(value)
        set_operation("xformOp:rotateXYZ", "float3", value)
      end

      # @return [Array<Float>, nil] scale operation
      def scale
        get("xformOp:scale")
      end

      # Author the scale operation.
      def scale=(value)
        set_operation("xformOp:scale", "float3", value)
      end

      private

      def set_operation(name, type_name, value)
        set(name, type_name, value)
        order = prim.attribute("xformOpOrder")&.get || []
        prim.create_attribute("xformOpOrder", "token[]").set(order + [name]) unless order.include?(name)
        value
      end
    end
  end
end
