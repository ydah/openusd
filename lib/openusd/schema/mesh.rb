# frozen_string_literal: true

module OpenUSD
  module Schema
    # Convenience API for core Mesh topology and point attributes.
    class Mesh < Base
      schema_type "Mesh"

      {
        points: ["points", "point3f[]"],
        normals: ["normals", "normal3f[]"],
        face_vertex_counts: ["faceVertexCounts", "int[]"],
        face_vertex_indices: ["faceVertexIndices", "int[]"],
        extent: ["extent", "float3[]"]
      }.each do |method_name, (attribute_name, type_name)|
        define_method(method_name) { get(attribute_name) }
        define_method("#{method_name}=") { |value| set(attribute_name, type_name, value) }
      end

      def subdivision_scheme
        get("subdivisionScheme")
      end

      def subdivision_scheme=(value)
        set("subdivisionScheme", "token", value)
      end
    end
  end
end
