# frozen_string_literal: true

module OpenUSD
  module Schema
    # Convenience API for Material prims.
    class Material < Base
      schema_type "Material"

      def bind(geometry_prim)
        geometry_prim.create_relationship("material:binding").set_targets([path])
        self
      end
    end
  end
end
