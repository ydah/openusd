# frozen_string_literal: true

module OpenUSD
  module Format
    # Extension-based registry for layer and package formats.
    module Registry
      Entry = Data.define(:reader, :writer)
      @entries = {}

      module_function

      def register(extension, reader: nil, writer: nil)
        key = normalize(extension)
        current = @entries[key]
        @entries[key] = Entry.new(
          reader: reader || current&.reader,
          writer: writer || current&.writer
        )
      end

      def fetch(path_or_extension)
        extension = File.extname(path_or_extension.to_s)
        key = normalize(extension.empty? ? path_or_extension : extension)
        @entries.fetch(key) { raise NotSupportedError, "unsupported file format: #{key}" }
      end

      def reader_for(path)
        fetch(path).reader || raise(NotSupportedError, "reading #{File.extname(path)} is not supported")
      end

      def writer_for(path)
        fetch(path).writer || raise(NotSupportedError, "writing #{File.extname(path)} is not supported")
      end

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
