# frozen_string_literal: true

require "fileutils"
require "zlib"

module OpenUSD
  module Format
    module Usdz
      # Reads and validates the constrained ZIP representation used by USDZ.
      class Reader
        Entry = Data.define(:name, :data, :data_offset)
        PACKAGE_URI = /\A(.+\.usdz)\[([^\]]+)\]\z/i
        LOCAL_SIGNATURE = 0x04034B50
        CENTRAL_SIGNATURE = 0x02014B50
        END_SIGNATURE = 0x06054B50

        class << self
          def read(path)
            package = new(path)
            root = package.entries.first
            raise PackageError, "USDZ package is empty" unless root

            parse_layer(package.path, root)
          end

          def read_uri(uri)
            package_path, entry_name = parse_uri(uri)
            package = new(package_path)
            entry = package.entry(entry_name)
            raise PackageError, "package entry not found: #{entry_name}" unless entry

            parse_layer(package.path, entry)
          end

          def parse_uri(uri)
            match = PACKAGE_URI.match(uri.to_s)
            raise PackageError, "invalid package URI: #{uri}" unless match

            [File.expand_path(match[1]), match[2]]
          end

          def parse_layer(package_path, root)
            extension = File.extname(root.name).downcase
            raise NotSupportedError, "USDC root layers are not supported" if extension == ".usdc"
            raise PackageError, "first USDZ entry must be a native USD layer" unless %w[.usd .usda].include?(extension)

            layer = Format::Usda::Parser.parse(root.data.dup.force_encoding(Encoding::UTF_8),
                                               file: "#{package_path}[#{root.name}]")
            layer.identifier = "#{File.expand_path(package_path)}[#{root.name}]"
            layer
          end

          def unpack(path, destination:)
            new(path).extract(destination)
          end
        end

        attr_reader :path

        def initialize(path)
          @path = File.expand_path(path)
          @archive = File.binread(@path)
          @entries = nil
        rescue Errno::ENOENT
          raise PackageError, "package not found: #{path}"
        end

        def entries
          @entries ||= parse_entries.freeze
        end

        def entry(name)
          entries.find { |candidate| candidate.name == name.to_s }
        end

        def extract(destination)
          root = File.expand_path(destination)
          entries.each do |entry|
            output = File.expand_path(entry.name, root)
            unless output.start_with?("#{root}#{File::SEPARATOR}")
              raise PackageError, "unsafe package entry: #{entry.name.inspect}"
            end

            FileUtils.mkdir_p(File.dirname(output))
            File.binwrite(output, entry.data)
          end
          entries.map(&:name)
        end

        private

        def parse_entries
          count, central_offset = end_directory
          offset = central_offset
          Array.new(count) do
            entry, offset = parse_central_entry(offset)
            entry
          end
        end

        def end_directory
          signature = [END_SIGNATURE].pack("V")
          offset = @archive.rindex(signature, [@archive.bytesize - 22, 0].max)
          raise PackageError, "missing ZIP end-of-directory record" unless offset

          fields = bytes(offset, 22).unpack("VvvvvVVv")
          _signature, disk, central_disk, disk_count, total_count, size, central_offset, comment_size = fields
          unsupported = disk != 0 || central_disk != 0 || disk_count != total_count || comment_size != 0
          raise PackageError, "multi-disk and commented ZIP files are not supported" if unsupported
          raise PackageError, "invalid central directory bounds" if central_offset + size > offset

          [total_count, central_offset]
        end

        def parse_central_entry(offset)
          fields = bytes(offset, 46).unpack("VvvvvvvVVVvvvvvVV")
          signature, _made, _needed, flags, method, _time, _date, crc, compressed_size,
            size, name_size, extra_size, comment_size, _disk, _internal, _external, local_offset = fields
          raise PackageError, "invalid central directory entry" unless signature == CENTRAL_SIGNATURE

          validate_storage!(flags, method, compressed_size, size)

          name = bytes(offset + 46, name_size).force_encoding(Encoding::UTF_8)
          validate_name!(name)
          data, data_offset = read_local_entry(local_offset, name, size, crc)
          next_offset = offset + 46 + name_size + extra_size + comment_size
          [Entry.new(name.freeze, data.freeze, data_offset), next_offset]
        end

        def read_local_entry(offset, expected_name, size, expected_crc)
          fields = bytes(offset, 30).unpack("VvvvvvVVVvv")
          signature, _needed, flags, method, _time, _date, crc, compressed_size,
            local_size, name_size, extra_size = fields
          raise PackageError, "invalid local ZIP header" unless signature == LOCAL_SIGNATURE

          validate_storage!(flags, method, compressed_size, local_size)
          raise PackageError, "central and local sizes differ" unless size == local_size

          name = bytes(offset + 30, name_size).force_encoding(Encoding::UTF_8)
          raise PackageError, "central and local names differ" unless name == expected_name

          data_offset = offset + 30 + name_size + extra_size
          raise PackageError, "USDZ entry is not 64-byte aligned" unless (data_offset % 64).zero?

          data = bytes(data_offset, size)
          actual_crc = Zlib.crc32(data)
          raise PackageError, "CRC mismatch for #{name}" unless crc == expected_crc && crc == actual_crc

          [data, data_offset]
        end

        def validate_storage!(flags, method, compressed_size, size)
          raise PackageError, "encrypted ZIP entries are not supported" unless flags.nobits?(1)
          raise PackageError, "USDZ entries must be uncompressed" unless method.zero? && compressed_size == size
        end

        def validate_name!(name)
          parts = name.tr("\\", "/").split("/")
          invalid = name.empty? || name.start_with?("/", "\\") || parts.include?("..")
          raise PackageError, "unsafe package entry: #{name.inspect}" if invalid
        end

        def bytes(offset, length)
          value = @archive.byteslice(offset, length)
          raise PackageError, "truncated ZIP structure" unless value&.bytesize == length

          value
        end
      end

      Format::Registry.register("usdz", reader: Reader)
    end
  end
end
