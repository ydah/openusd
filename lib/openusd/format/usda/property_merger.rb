# frozen_string_literal: true

module OpenUSD
  module Format
    module Usda
      # Combines fields from repeated USDA declarations into one property spec.
      module PropertyMerger
        module_function

        # Merge a parsed property into its owning prim.
        # @return [AttributeSpec, RelationshipSpec]
        def merge(prim, property)
          existing = prim.property_named(property.name)
          return prim.add_property(property) unless existing

          unless existing.instance_of?(property.class)
            raise OpenUSD::TypeError, "property #{property.name} is declared with conflicting kinds"
          end

          existing.is_a?(AttributeSpec) ? merge_attribute(existing, property) : merge_relationship(existing, property)
          existing
        end

        def merge_attribute(existing, property)
          unless existing.type_name == property.type_name
            raise OpenUSD::TypeError, "attribute #{property.name} is declared with conflicting types"
          end

          existing.custom ||= property.custom
          existing.variability = :uniform if property.variability == :uniform
          existing.metadata.merge!(property.metadata)
          existing.set(property.default) if property.default_authored?
          existing.time_samples = property.time_samples if property.time_samples_authored?
          existing.connections = property.connections if property.connections_authored?
        end
        private_class_method :merge_attribute

        def merge_relationship(existing, property)
          existing.custom ||= property.custom
          existing.metadata.merge!(property.metadata)
          existing.targets = property.targets if property.targets_authored?
        end
        private_class_method :merge_relationship
      end
    end
  end
end
