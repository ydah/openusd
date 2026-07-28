# frozen_string_literal: true

require "pathname"

module OpenUSD
  # Resolves authored asset paths relative to their containing layer.
  class AssetResolver
    # Supported unresolved-asset behaviors.
    MISSING_POLICIES = %i[error warn ignore].freeze

    attr_reader :search_paths, :missing_assets

    def initialize(search_paths: [], missing_assets: :error)
      @search_paths = search_paths.map { |path| File.expand_path(path) }.freeze
      @missing_assets = missing_assets.to_sym
      return if MISSING_POLICIES.include?(@missing_assets)

      raise ArgumentError, "invalid missing-assets policy: #{missing_assets.inspect}"
    end

    # Resolve an asset path, optionally anchored to a layer identifier.
    # @return [String, nil]
    def resolve(asset_path, anchor: nil)
      authored = asset_path.is_a?(AssetPath) ? asset_path.path : asset_path.to_s
      return resolve_package_asset(authored, anchor) if package_uri?(anchor)
      return File.expand_path(anchor) if authored.empty? && anchor

      resolved = candidates(authored, anchor).find { |candidate| File.file?(candidate) }
      return resolved if resolved

      missing(authored, anchor)
    end

    private

    def package_uri?(value)
      value&.match?(/\A.+\.usdz\[[^\]]+\]\z/i)
    end

    def resolve_package_asset(authored, anchor)
      package, entry_name = Format::Usdz::Reader.parse_uri(anchor)
      normalized = File.expand_path(authored, "/#{File.dirname(entry_name)}").delete_prefix("/")
      unsafe = normalized.start_with?("../") || authored.start_with?("/")
      return missing(authored, anchor) if unsafe

      return "#{package}[#{normalized}]" if Format::Usdz::Reader.new(package).entry(normalized)

      missing(authored, anchor)
    end

    def candidates(authored, anchor)
      return [File.expand_path(authored)] if Pathname.new(authored).absolute?

      roots = []
      roots << File.dirname(File.expand_path(anchor)) if anchor && !anchor.start_with?("anonymous:")
      roots.concat(search_paths)
      roots << Dir.pwd if roots.empty?
      roots.uniq.map { |root| File.expand_path(authored, root) }
    end

    def missing(authored, anchor)
      message = "asset not found: #{authored.inspect}"
      message += " (relative to #{anchor})" if anchor
      raise CompositionError, message if missing_assets == :error

      warn(message) if missing_assets == :warn
      nil
    end
  end
end
