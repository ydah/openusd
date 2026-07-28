# frozen_string_literal: true

module OpenUSD
  module Format
    module Usda
      # Recursive-descent parser for USDA layers.
      class Parser
        # Authored prim specifier keywords.
        SPECIFIERS = %w[def over class].freeze
        # Recognized list-edit operation keywords.
        LIST_OPERATIONS = %w[prepend append delete reorder add explicit].freeze
        # Recognized property qualifiers.
        QUALIFIERS = %w[custom uniform varying].freeze

        class << self
          # Parse a USDA string.
          # @return [Layer]
          def parse(source, file: nil)
            new(source, file: file).parse
          end
        end

        attr_reader :file

        def initialize(source, file: nil)
          @lexer = Lexer.new(source, file: file)
          @file = file
          advance
        end

        # Parse the configured source.
        # @return [Layer]
        def parse
          header = expect(:magic, description: "USDA header")
          error!("unsupported USDA version #{header.value}") unless header.value == "1.0"

          layer = Layer.new(file)
          layer.metadata.merge!(parse_metadata_block) if symbol?("(")
          layer.add_root_prim(parse_prim) until current.type == :eof
          layer
        rescue OpenUSD::PathError, OpenUSD::TypeError => e
          error!(e.message)
        end

        private

        attr_reader :current

        def parse_prim
          specifier = expect_identifier
          error!("expected prim specifier") unless SPECIFIERS.include?(specifier)

          type_name = expect_identifier unless current.type == :string
          name = expect(:string, description: "prim name").value
          metadata = symbol?("(") ? parse_metadata_block : {}
          references = extract_references!(metadata)
          prim = PrimSpec.new(
            name,
            type_name: type_name,
            specifier: specifier,
            metadata: metadata,
            references: references
          )
          parse_prim_body(prim)
          prim
        end

        def parse_prim_body(prim)
          expect_symbol("{")
          until accept_symbol?("}")
            if specifier?
              prim.add_child(parse_prim)
            elsif identifier?("variantSet")
              parse_variant_set(prim)
            else
              prim.add_property(parse_property)
            end
          end
        end

        def parse_variant_set(prim)
          advance
          name = expect(:string, description: "variant set name").value
          expect_symbol("=")
          expect_symbol("{")
          choices = {}
          until accept_symbol?("}")
            choice = expect(:string, description: "variant name").value
            holder = PrimSpec.new("_variant")
            parse_prim_body(holder)
            choices[choice] = Variant.new(holder.properties.freeze, holder.children.freeze)
          end
          prim.variant_sets[name] = choices
        end

        def parse_property
          qualifiers = []
          qualifiers << consume_identifier while current.type == :identifier && QUALIFIERS.include?(current.value)

          return parse_relationship(qualifiers) if identifier?("rel")

          type_name = expect_identifier
          name = expect_identifier
          suffix = parse_property_suffix
          value = parse_assigned_value(type_name)
          metadata = symbol?("(") ? parse_metadata_block : {}
          build_attribute(name, type_name, suffix, value, qualifiers, metadata)
        end

        def parse_relationship(qualifiers)
          advance
          name = expect_identifier
          value = accept_symbol?("=") ? parse_value : RelationshipSpec::UNAUTHORED
          metadata = symbol?("(") ? parse_metadata_block : {}
          targets = value.equal?(RelationshipSpec::UNAUTHORED) ? value : unwrap_list(value).compact
          RelationshipSpec.new(name, targets: targets, custom: qualifiers.include?("custom"), metadata: metadata)
        end

        def parse_property_suffix
          return unless accept_symbol?(".")

          expect_identifier
        end

        def parse_assigned_value(type_name)
          return AttributeSpec::UNAUTHORED unless accept_symbol?("=")

          parse_value(type_name)
        end

        def build_attribute(name, type_name, suffix, value, qualifiers, metadata)
          attribute = AttributeSpec.new(
            name, type_name,
            variability: qualifiers.include?("uniform") ? :uniform : :varying,
            custom: qualifiers.include?("custom"),
            metadata: metadata
          )
          apply_attribute_value(attribute, suffix, value)
          attribute
        end

        def apply_attribute_value(attribute, suffix, value)
          case suffix
          when "timeSamples"
            attribute.time_samples = value
          when "connect"
            attribute.connections = unwrap_list(value)
          when nil
            attribute.set(value) unless value.equal?(AttributeSpec::UNAUTHORED)
          else
            attribute.metadata[suffix] = value
          end
        end

        def parse_metadata_block
          expect_symbol("(")
          metadata = {}
          metadata.merge!(parse_metadata_entry) until accept_symbol?(")")
          metadata
        end

        def parse_metadata_entry
          operation = consume_identifier if current.type == :identifier && LIST_OPERATIONS.include?(current.value)
          first = expect_identifier
          type_name, key = metadata_type_and_key(first)
          expect_symbol("=")
          value = parse_value(type_name)
          value = ListOp.new(operation, value) if operation
          { key => value }
        end

        def metadata_type_and_key(first)
          return [nil, first] unless current.type == :identifier

          [first, consume_identifier]
        end

        def parse_value(expected_type = nil)
          case current.type
          when :string, :number then consume.value
          when :asset then parse_asset
          when :path then Path.parse(consume.value)
          when :identifier then parse_identifier_value
          when :symbol then parse_compound_value(expected_type)
          else error!("expected a value")
          end
        end

        def parse_asset
          asset = AssetPath.new(consume.value)
          return asset unless current.type == :path

          Reference.new(asset, Path.parse(consume.value))
        end

        def parse_identifier_value
          value = consume.value
          return true if value == "true"
          return false if value == "false"
          return nil if value == "None"
          return Float::INFINITY if value == "inf"
          return -Float::INFINITY if value == "-inf"
          return Float::NAN if value == "nan"

          Token.new(value)
        end

        def parse_compound_value(expected_type)
          return parse_sequence("(", ")", expected_type) if symbol?("(")
          return parse_array(expected_type) if symbol?("[")
          return parse_dictionary if symbol?("{")

          error!("expected a value")
        end

        def parse_array(expected_type)
          base_type = Types.base_type(expected_type.to_s)
          component_count = Types::VECTOR_TYPES[base_type]
          numeric = component_count || Types::FLOAT_TYPES.include?(base_type) ||
                    Types::INTEGER_RANGES.key?(base_type)
          return parse_sequence("[", "]", base_type) unless numeric

          values = @lexer.scan_numeric_array(component_count: component_count)
          return parse_sequence("[", "]", base_type) unless values

          advance
          values
        end

        def parse_sequence(opening, closing, expected_type)
          expect_symbol(opening)
          values = []
          until accept_symbol?(closing)
            values << parse_value(expected_type)
            accept_symbol?(",")
          end
          values
        end

        def parse_dictionary
          expect_symbol("{")
          values = {}
          until accept_symbol?("}")
            key, type_name, separator = parse_dictionary_key
            expect_symbol(separator)
            values[key] = parse_value(type_name)
            accept_symbol?(",")
          end
          values
        end

        def parse_dictionary_key
          return [consume.value, nil, ":"] if current.type == :number

          first = consume
          error!("expected dictionary key") unless %i[string identifier].include?(first.type)
          return [first.value, nil, current.value] if symbol?(":") || symbol?("=")

          [expect_identifier, first.value, "="]
        end

        def extract_references!(metadata)
          value = metadata.delete("references")
          return [] unless value

          Array(unwrap_list(value)).map do |reference|
            reference.is_a?(Reference) ? reference : Reference.new(reference)
          end
        end

        def unwrap_list(value)
          value = value.value if value.is_a?(ListOp)
          value.is_a?(Array) ? value : [value]
        end

        def specifier?
          current.type == :identifier && SPECIFIERS.include?(current.value)
        end

        def identifier?(value)
          current.type == :identifier && current.value == value
        end

        def symbol?(value)
          current.type == :symbol && current.value == value
        end

        def accept_symbol?(value)
          return false unless symbol?(value)

          advance
          true
        end

        def expect_symbol(value)
          expect(:symbol, value: value, description: value)
        end

        def expect_identifier
          expect(:identifier, description: "identifier").value
        end

        def consume_identifier
          expect_identifier
        end

        def expect(type, value: nil, description: type)
          token = current
          matches = token.type == type && (value.nil? || token.value == value)
          error!("expected #{description}, got #{token.raw.inspect}") unless matches
          advance
          token
        end

        def consume
          token = current
          advance
          token
        end

        def advance
          @current = @lexer.next_token
        end

        def error!(message)
          raise ParseError.new(message, file: file, line: current.line, column: current.column)
        end
      end

      # File reader adapter for the format registry.
      module Reader
        module_function

        # Read a USDA layer from a filesystem path.
        # @return [Layer]
        def read(path)
          Parser.parse(File.binread(path).force_encoding(Encoding::UTF_8), file: path)
        rescue Errno::ENOENT
          raise CompositionError, "layer not found: #{path}"
        end
      end
    end
  end
end
