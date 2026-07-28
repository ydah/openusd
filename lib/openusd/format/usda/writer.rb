# frozen_string_literal: true

module OpenUSD
  module Format
    module Usda
      # Deterministic USDA serializer.
      class Writer
        # Indentation used for nested USDA constructs.
        INDENT = " " * 4

        class << self
          # Serialize a layer to a filesystem path.
          # @return [String] destination path
          def write(layer, path)
            File.binwrite(path, new.write_to_string(layer))
            path
          end
        end

        # Serialize a layer to USDA text.
        # @return [String]
        def write_to_string(layer)
          @lines = ["#usda 1.0"]
          write_metadata_block(layer.metadata, 0, layer_comment: true) unless layer.metadata.empty?
          layer.root_prims.each do |prim|
            line
            write_prim(prim, 0)
          end
          "#{@lines.join("\n")}\n"
        ensure
          @lines = nil
        end

        private

        def write_prim(prim, depth)
          declaration = "#{prim.specifier}#{type_declaration(prim.type_name)} #{quote(prim.name)}"
          metadata = prim.metadata.dup
          write_references_metadata(metadata, prim) if prim.references_authored?
          append(declaration, depth)
          write_metadata_block(metadata, depth) unless metadata.empty?
          append("{", depth)
          write_prim_contents(prim, depth + 1)
          append("}", depth)
        end

        def write_prim_contents(prim, depth)
          ordered_properties(prim).each { |property| write_property(property, depth) }
          write_variants(prim, depth)
          prim.children.each do |child|
            line
            write_prim(child, depth)
          end
        end

        def ordered_properties(prim)
          prim.properties.sort_by do |property|
            if property.is_a?(RelationshipSpec)
              2
            elsif property.variability == :uniform
              0
            else
              1
            end
          end
        end

        def write_property(property, depth)
          if property.is_a?(RelationshipSpec)
            write_relationship(property, depth)
          else
            write_attribute(property, depth)
          end
        end

        def write_attribute(attribute, depth)
          prefix = attribute_prefix(attribute)
          wrote_declaration = false
          if attribute.default_authored?
            write_property_line("#{prefix} = #{format_value(attribute.default, attribute.type_name, depth)}",
                                attribute.metadata, depth)
            wrote_declaration = true
          elsif !attribute.metadata.empty?
            write_property_line(prefix, attribute.metadata, depth)
            wrote_declaration = true
          end
          write_time_samples(attribute, prefix, depth) if attribute.time_samples_authored?
          write_connections(attribute, prefix, depth) if attribute.connections_authored?
          authored = wrote_declaration || attribute.time_samples_authored? || attribute.connections_authored?
          write_property_line(prefix, attribute.metadata, depth) unless authored
        end

        def write_time_samples(attribute, prefix, depth)
          append("#{prefix}.timeSamples = {", depth)
          attribute.time_samples.each do |time, value|
            formatted = format_value(value, attribute.type_name, depth + 1)
            append("#{format_number(time)}: #{formatted},", depth + 1)
          end
          append("}", depth)
        end

        def write_connections(attribute, prefix, depth)
          value = attribute.connections.length == 1 ? attribute.connections.first : attribute.connections
          append("#{prefix}.connect = #{format_value(value, nil, depth)}", depth)
        end

        def write_relationship(relationship, depth)
          prefix = relationship.custom ? "custom rel #{relationship.name}" : "rel #{relationship.name}"
          value = relationship.targets.length == 1 ? relationship.targets.first : relationship.targets
          text = if relationship.targets_authored?
                   "#{prefix} = #{format_value(value, nil, depth)}"
                 else
                   prefix
                 end
          write_property_line(text, relationship.metadata, depth)
        end

        def write_property_line(text, metadata, depth)
          if metadata.empty?
            append(text, depth)
          else
            append(text, depth)
            write_metadata_block(metadata, depth)
          end
        end

        def write_metadata_block(metadata, depth, layer_comment: false)
          append("(", depth)
          metadata.each do |key, value|
            if layer_comment && key == "comment" && value.is_a?(String)
              append(quote(value), depth + 1)
              next
            end

            operation, unwrapped = unwrap_list_op(value)
            prefix = operation ? "#{operation} " : ""
            write_metadata_entry("#{prefix}#{key}", unwrapped, depth + 1)
          end
          append(")", depth)
        end

        def write_metadata_entry(key, value, depth)
          if value.is_a?(Hash)
            append("#{key} = {", depth)
            write_dictionary(value, depth + 1)
            append("}", depth)
          else
            append("#{key} = #{format_value(value, nil, depth)}", depth)
          end
        end

        def write_dictionary(dictionary, depth)
          dictionary.each do |key, value|
            type_name = infer_type(value)
            if value.is_a?(Hash)
              append("dictionary #{key} = {", depth)
              write_dictionary(value, depth + 1)
              append("}", depth)
            else
              append("#{type_name} #{key} = #{format_value(value, type_name, depth)}", depth)
            end
          end
        end

        def write_variants(prim, depth)
          prim.variant_sets.each do |name, choices|
            line
            append("variantSet #{quote(name)} = {", depth)
            choices.each do |choice, variant|
              append("#{quote(choice)} {", depth + 1)
              variant.properties.each { |property| write_property(property, depth + 2) }
              variant.children.each { |child| write_prim(child, depth + 2) }
              append("}", depth + 1)
            end
            append("}", depth)
          end
        end

        def format_value(value, expected_type, depth)
          return "None" if value.nil?
          return format_reference(value) if value.is_a?(Reference)
          return format_asset(value) if value.is_a?(AssetPath)
          return "<#{value}>" if value.is_a?(Path)
          return quote(value) if value.is_a?(String)
          return value ? "true" : "false" if [true, false].include?(value)
          return format_number(value) if value.is_a?(Numeric)
          return format_array(value, expected_type, depth) if value.is_a?(Array)
          return format_inline_dictionary(value, depth) if value.is_a?(Hash)

          value.to_s
        end

        def format_array(values, expected_type, depth)
          scalar_value = expected_type && !Types.array?(expected_type)
          vector = scalar_value && Types::VECTOR_TYPES.key?(Types.base_type(expected_type))
          matrix = scalar_value && Types::MATRIX_TYPES.key?(Types.base_type(expected_type))
          opening, closing = vector || matrix ? ["(", ")"] : ["[", "]"]
          element_type = Types.array?(expected_type.to_s) ? Types.base_type(expected_type) : nil
          contents = if matrix
                       values.map { |row| format_array(row, "double4", depth) }.join(", ")
                     else
                       values.map { |value| format_value(value, element_type, depth) }.join(", ")
                     end
          "#{opening}#{contents}#{closing}"
        end

        def format_inline_dictionary(dictionary, depth)
          return "{}" if dictionary.empty?

          parts = dictionary.map { |key, value| "#{key}: #{format_value(value, nil, depth + 1)}" }
          "{ #{parts.join(", ")} }"
        end

        def format_reference(reference)
          return "<#{reference.prim_path}>" if reference.internal?

          asset = format_asset(reference.asset_path)
          reference.prim_path ? "#{asset}<#{reference.prim_path}>" : asset
        end

        def format_asset(asset)
          delimiter = asset.path.include?("@") ? "@@@" : "@"
          "#{delimiter}#{asset.path}#{delimiter}"
        end

        def format_number(number)
          return "nan" if number.respond_to?(:nan?) && number.nan?
          return number.negative? ? "-inf" : "inf" if number.respond_to?(:infinite?) && number.infinite?
          return number.to_s unless number.is_a?(Float)

          number.to_s
        end

        def infer_type(value)
          return "bool" if [true, false].include?(value)
          return "int" if value.is_a?(Integer)
          return "double" if value.is_a?(Float)
          return "asset" if value.is_a?(AssetPath)
          return "token" if value.is_a?(Token)
          return "string" if value.is_a?(String)

          "string"
        end

        def quote(value)
          escaped = value.to_s.gsub("\\", "\\\\").gsub("\"", "\\\"")
                         .gsub("\n", "\\n").gsub("\r", "\\r").gsub("\t", "\\t")
          "\"#{escaped}\""
        end

        def type_declaration(type_name)
          type_name.nil? || type_name.empty? ? "" : " #{type_name}"
        end

        def attribute_prefix(attribute)
          qualifiers = []
          qualifiers << "custom" if attribute.custom
          qualifiers << "uniform" if attribute.variability == :uniform
          [*qualifiers, attribute.type_name, attribute.name].join(" ")
        end

        def reference_value(references)
          references.length == 1 ? references.first : references
        end

        def write_references_metadata(metadata, prim)
          value = reference_value(prim.references)
          value = ListOp.new(prim.reference_list_op, value) if prim.reference_list_op
          metadata["references"] = value
        end

        def unwrap_list_op(value)
          return [value.operation, value.value] if value.is_a?(ListOp)

          [nil, value]
        end

        def append(text, depth)
          @lines << "#{INDENT * depth}#{text}"
        end

        def line
          @lines << ""
        end
      end

      Format::Registry.register("usda", reader: Reader, writer: Writer)
      Format::Registry.register("usd", reader: Reader, writer: Writer)
    end
  end
end
