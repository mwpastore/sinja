# frozen_string_literal: true
require 'jsonapi-serializers'

module JSONAPI
  module EmberSerializer
    def self.included(base)
      base.class_eval do
        include Serializer

        alias type_for_link type
        alias format_name_for_link format_name

        include InstanceMethods
      end
    end

    module InstanceMethods
      def type
        object.class.name.demodulize.underscore.dasherize
      end

      def format_name(attribute_name)
        attribute_name.to_s.underscore.camelize(:lower)
      end

      def self_link
        "#{base_url}/#{type_for_link}/#{id}"
      end

      def relationship_self_link(attribute_name)
        "#{self_link}/relationships/#{format_name_for_link(attribute_name)}"
      end

      def relationship_related_link(attribute_name)
        "#{self_link}/#{format_name_for_link(attribute_name)}"
      end
    end
  end
end
