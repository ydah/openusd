# frozen_string_literal: true

require "pathname"
require "zlib"

module OpenUSD
  module Format
    module Usdz
      # Writes uncompressed, 64-byte-aligned USDZ packages.
      module Writer
        LOCAL_SIGNATURE = 0x04034B50
        CENTRAL_SIGNATURE = 0x02014B50
        END_SIGNATURE = 0x06054B50
        ALIGNMENT_EXTRA_ID = 0x1986
        UINT32_MAX = (2**32) - 1

        module_function

        def write(layer, path)
          root_name = "#{File.basename(path, File.extname(path))}.usda"
          write_entries(path, [[root_name, layer.to_usda]])
          path
        end

        def pack(path, root:, assets: [])
          root_path = File.expand_path(root)
          validate_root!(root_path)
          entries = [[File.basename(root_path), File.binread(root_path)]]
          entries.concat(Array(assets).map { |asset| asset_entry(asset) })
          write_entries(path, entries)
          path
        rescue Errno::ENOENT => e
          raise PackageError, "package input not found: #{e.message}"
        end

        def write_entries(path, entries)
          validate_entries!(entries)
          archive = String.new(encoding: Encoding::BINARY)
          central_records = entries.map { |name, data| write_local_entry(archive, name, data.b) }
          central_offset = archive.bytesize
          central_records.each { |record| archive << central_header(record) }
          central_size = archive.bytesize - central_offset
          archive << end_record(entries.length, central_size, central_offset)
          File.binwrite(path, archive)
        end

        def write_local_entry(archive, name, data)
          name = name.encode(Encoding::UTF_8)
          flags = name.ascii_only? ? 0 : (1 << 11)
          crc = Zlib.crc32(data)
          local_offset = archive.bytesize
          extra = alignment_extra(local_offset + 30 + name.bytesize)
          header = [
            LOCAL_SIGNATURE, 10, flags, 0, 0, 0, crc,
            data.bytesize, data.bytesize, name.bytesize, extra.bytesize
          ].pack("VvvvvvVVVvv")
          archive << header << name.b << extra << data
          {
            name: name, flags: flags, crc: crc, size: data.bytesize,
            local_offset: local_offset
          }
        end
        private_class_method :write_local_entry

        def alignment_extra(base_offset)
          extra_size = (-base_offset) % 64
          extra_size += 64 if extra_size.positive? && extra_size < 4
          return "".b if extra_size.zero?

          [ALIGNMENT_EXTRA_ID, extra_size - 4].pack("vv") + ("\0".b * (extra_size - 4))
        end
        private_class_method :alignment_extra

        def central_header(record)
          name = record.fetch(:name)
          [
            CENTRAL_SIGNATURE, 20, 10, record.fetch(:flags), 0, 0, 0,
            record.fetch(:crc), record.fetch(:size), record.fetch(:size),
            name.bytesize, 0, 0, 0, 0, 0, record.fetch(:local_offset)
          ].pack("VvvvvvvVVVvvvvvVV") + name.b
        end
        private_class_method :central_header

        def end_record(count, central_size, central_offset)
          [END_SIGNATURE, 0, 0, count, count, central_size, central_offset, 0].pack("VvvvvVVv")
        end
        private_class_method :end_record

        def asset_entry(asset)
          source, authored_name = asset.is_a?(Hash) ? asset.values_at(:source, :path) : [asset, asset]
          source = File.expand_path(source)
          name = Pathname.new(authored_name.to_s).absolute? ? File.basename(authored_name) : authored_name.to_s
          [normalize_entry_name(name), File.binread(source)]
        end
        private_class_method :asset_entry

        def validate_root!(path)
          extension = File.extname(path).downcase
          return if %w[.usd .usda .usdc].include?(extension)

          raise PackageError, "USDZ root must be a .usd, .usda, or .usdc file"
        end
        private_class_method :validate_root!

        def validate_entries!(entries)
          raise PackageError, "USDZ package requires a root layer" if entries.empty?
          raise PackageError, "too many ZIP entries" if entries.length > 65_535

          names = entries.map do |name, data|
            normalized = normalize_entry_name(name)
            raise PackageError, "ZIP64 packages are not supported" if data.bytesize > UINT32_MAX

            normalized
          end
          raise PackageError, "duplicate package entry" unless names.uniq.length == names.length
        end
        private_class_method :validate_entries!

        def normalize_entry_name(name)
          normalized = name.to_s.tr("\\", "/").delete_prefix("./")
          parts = normalized.split("/")
          invalid = normalized.empty? || normalized.start_with?("/") || parts.include?("..")
          raise PackageError, "unsafe package entry: #{name.inspect}" if invalid
          raise PackageError, "package entry name is too long" if normalized.bytesize > 65_535

          normalized
        end
        private_class_method :normalize_entry_name
      end

      Format::Registry.register("usdz", writer: Writer)
    end
  end
end
