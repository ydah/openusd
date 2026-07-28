# frozen_string_literal: true

module OpenUSD
  # Typed convenience wrappers for commonly authored prim schemas.
  module Schema
    # Base for typed convenience wrappers around Stage prims.
    class Base
      class << self
        attr_reader :type_name

        # Declare the prim type represented by a wrapper.
        # @api private
        def schema_type(name)
          @type_name = name.freeze
        end

        # Define and wrap a prim.
        # @return [Base]
        def define(stage, path)
          new(stage.define_prim(path, type_name))
        end

        # Wrap a prim only when its type matches.
        # @return [Base, nil]
        def get(stage, path)
          prim = stage.prim_at(path)
          return unless prim&.type_name == type_name

          new(prim)
        end
      end

      attr_reader :prim

      def initialize(prim)
        @prim = prim
      end

      # @return [Stage] owning stage
      def stage
        prim.stage
      end

      # @return [Path] wrapped prim path
      def path
        prim.path
      end

      private

      def get(name)
        prim.attribute(name)&.get
      end

      def set(name, type_name, value)
        prim.create_attribute(name, type_name).set(value)
        self
      end
    end
  end
end
