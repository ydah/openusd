# frozen_string_literal: true

require "strscan"

module OpenUSD
  module Format
    # USDA text format support.
    module Usda
      # Converts USDA text into location-aware tokens.
      class Lexer
        # One lexeme and its source location.
        Token = Data.define(:type, :value, :line, :column, :raw)
        # Single-character grammar symbols.
        SYMBOLS = "(){}[]=,:."
        # Supported string escape translations.
        ESCAPES = {
          "n" => "\n", "r" => "\r", "t" => "\t", "b" => "\b",
          "f" => "\f", "\\" => "\\", "\"" => "\""
        }.freeze

        attr_reader :file

        def initialize(source, file: nil)
          @scanner = StringScanner.new(String(source).delete_prefix("\uFEFF"))
          @file = file
          @line = 1
          @column = 1
        end

        # Iterate through all tokens, including the final EOF token.
        def each_token
          return enum_for(__method__) unless block_given?

          loop do
            token = next_token
            yield token
            break if token.type == :eof
          end
        end

        # @return [Token] next token from the source
        def next_token
          skip_ignored
          return token(:eof, nil, "") if @scanner.eos?

          return scan_magic if @scanner.match?(/#usda\b/)
          return scan_quoted("\"\"\"", :string) if @scanner.peek(3) == "\"\"\""
          return scan_quoted("\"", :string) if @scanner.peek(1) == "\""
          return scan_quoted("@@@", :asset) if @scanner.peek(3) == "@@@"
          return scan_quoted("@", :asset) if @scanner.peek(1) == "@"
          return scan_path if @scanner.peek(1) == "<"

          scan_bare_token
        end

        private

        def scan_bare_token
          return scan_special_number if @scanner.match?(/[+-]?(?:inf|nan)\b/)
          return scan_number if @scanner.match?(/[+-]?(?:\d|\.\d)/)
          return scan_identifier if @scanner.match?(/[\p{L}_]/u)
          return scan_symbol if SYMBOLS.include?(@scanner.peek(1))

          lexical_error!("unexpected character #{@scanner.peek(1).inspect}")
        end

        def skip_ignored
          loop do
            skipped = scan_ignored_pattern?(/[ \t\r\n]+/)
            skipped ||= scan_line_comment?("#") unless @scanner.match?(/#usda\b/)
            skipped ||= scan_line_comment?("//")
            skipped ||= scan_block_comment?
            break unless skipped
          end
        end

        def scan_ignored_pattern?(pattern)
          raw = @scanner.scan(pattern)
          return false unless raw

          advance(raw)
          true
        end

        def scan_line_comment?(prefix)
          return false unless @scanner.peek(prefix.length) == prefix

          raw = @scanner.scan(/.*(?:\n|\z)/)
          advance(raw)
          true
        end

        def scan_block_comment?
          return false unless @scanner.peek(2) == "/*"

          start_line = @line
          start_column = @column
          raw = @scanner.scan(%r{/\*.*?\*/}m)
          lexical_error!("unterminated block comment", start_line, start_column) unless raw
          advance(raw)
          true
        end

        def scan_magic
          line = @line
          column = @column
          raw = @scanner.scan(/#usda[ \t]+([0-9]+(?:\.[0-9]+)?)/)
          lexical_error!("invalid USDA header", line, column) unless raw
          version = @scanner[1]
          advance(raw)
          Token.new(:magic, version, line, column, raw)
        end

        def scan_quoted(delimiter, type)
          line = @line
          column = @column
          raw = consume(delimiter)
          value = +""

          until @scanner.eos?
            if @scanner.peek(delimiter.length) == delimiter
              raw << consume(delimiter)
              return Token.new(type, value.freeze, line, column, raw.freeze)
            end

            character = consume_character
            raw << character
            if character == "\\" && type == :string
              escaped = consume_character
              raw << escaped
              value << ESCAPES.fetch(escaped, escaped)
            else
              value << character
            end
          end

          lexical_error!("unterminated #{type}", line, column)
        end

        def scan_path
          line = @line
          column = @column
          raw = consume("<")
          value = +""

          until @scanner.eos?
            character = consume_character
            raw << character
            return Token.new(:path, value.freeze, line, column, raw.freeze) if character == ">"

            value << character
          end

          lexical_error!("unterminated path", line, column)
        end

        def scan_number
          line = @line
          column = @column
          raw = @scanner.scan(/[+-]?(?:(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?)/)
          value = raw.match?(/[.eE]/) ? Float(raw) : Integer(raw, 10)
          advance(raw)
          Token.new(:number, value, line, column, raw.freeze)
        end

        def scan_special_number
          line = @line
          column = @column
          raw = @scanner.scan(/[+-]?(?:inf|nan)\b/)
          value = if raw.include?("nan")
                    Float::NAN
                  elsif raw.start_with?("-")
                    -Float::INFINITY
                  else
                    Float::INFINITY
                  end
          advance(raw)
          Token.new(:number, value, line, column, raw.freeze)
        end

        def scan_identifier
          line = @line
          column = @column
          raw = @scanner.scan(/[\p{L}_][\p{L}\p{N}_:]*(?:\[\])?/u)
          advance(raw)
          Token.new(:identifier, raw.freeze, line, column, raw.freeze)
        end

        def scan_symbol
          line = @line
          column = @column
          raw = consume_character
          Token.new(:symbol, raw, line, column, raw)
        end

        def consume(expected)
          raw = @scanner.scan(Regexp.new(Regexp.escape(expected)))
          advance(raw)
          raw
        end

        def consume_character
          raw = @scanner.getch
          advance(raw)
          raw
        end

        def advance(raw)
          lines = raw.count("\n")
          if lines.zero?
            @column += raw.length
          else
            @line += lines
            @column = raw.length - raw.rindex("\n")
          end
        end

        def token(type, value, raw)
          Token.new(type, value, @line, @column, raw)
        end

        def lexical_error!(message, line = @line, column = @column)
          raise ParseError.new(message, file: file, line: line, column: column)
        end
      end
    end
  end
end
