# frozen_string_literal: true

module OpenUSD
  # Base class for errors raised by this library.
  class Error < StandardError; end

  # Raised when USDA text cannot be parsed.
  class ParseError < Error
    attr_reader :file, :line, :column

    def initialize(message, file: nil, line: nil, column: nil)
      @file = file
      @line = line
      @column = column
      super(location ? "#{location}: #{message}" : message)
    end

    private

    def location
      return unless line && column

      [file, line, column].compact.join(":")
    end
  end

  # Raised when a Ruby value does not conform to a USD value type.
  class TypeError < Error; end

  # Raised when an Sdf-style path is malformed or invalid for an operation.
  class PathError < Error; end

  # Raised when layers cannot be composed.
  class CompositionError < Error; end

  # Raised when a USDZ package is malformed or violates package constraints.
  class PackageError < Error; end

  # Raised for recognized operations that are outside this implementation.
  class NotSupportedError < Error; end
end
