# frozen_string_literal: true

module OpenUSD
  module Format
    module Usda
      # Converts a USDA references metadata field to model references.
      module ReferenceMetadata
        module_function

        # Remove and normalize references metadata.
        # @return [Array(Array<Reference>, Symbol, Boolean)]
        def extract(metadata)
          return [[], nil, false] unless metadata.key?("references")

          value = metadata.delete("references")
          operation = value.operation if value.is_a?(ListOp)
          value = value.value if value.is_a?(ListOp)
          references = Array(unwrap_list(value)).map { |reference| normalize(reference) }
          [references, operation, true]
        end

        def normalize(reference)
          return Reference.internal(reference) if reference.is_a?(Path)
          return reference if reference.is_a?(Reference)

          Reference.new(reference)
        end
        private_class_method :normalize

        def unwrap_list(value)
          value.is_a?(Array) ? value : [value]
        end
        private_class_method :unwrap_list
      end
    end
  end
end
