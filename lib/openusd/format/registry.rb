# frozen_string_literal: true

module OpenUSD
  # File-format adapters and the extension registry.
  module Format
    # Extension-based registry for layer and package formats.
    module Registry
      # Registered reader/writer pair.
      Entry = Data.define(:reader, :writer)
      @entries = {}

      module_function

      # Register one or both adapters for an extension.
      def register(extension, reader: nil, writer: nil)
        key = normalize(extension)
        current = @entries[key]
        @entries[key] = Entry.new(
          reader: reader || current&.reader,
          writer: writer || current&.writer
        )
      end

      # @return [Entry] adapter pair for a path or extension
      def fetch(path_or_extension)
        extension = File.extname(path_or_extension.to_s)
        key = normalize(extension.empty? ? path_or_extension : extension)
        @entries.fetch(key) { raise NotSupportedError, "unsupported file format: #{key}" }
      end

      # @return [#read] reader adapter for a path
      def reader_for(path)
        fetch(path).reader || raise(NotSupportedError, "reading #{File.extname(path)} is not supported")
      end

      # @return [#write] writer adapter for a path
      def writer_for(path)
        fetch(path).writer || raise(NotSupportedError, "writing #{File.extname(path)} is not supported")
      end

      # @return [Array<String>] registered extensions without leading dots
      def extensions
        @entries.keys.freeze
      end

      def normalize(extension)
        extension.to_s.downcase.delete_prefix(".")
      end
      private_class_method :normalize
    end
  end
end
