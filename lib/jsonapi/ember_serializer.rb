# frozen_string_literal: true
require 'jsonapi-serializers'

module JSONAPI
  module EmberSerializer
    def self.included(base)
      base.class_eval do
        include Serializer

        alias_method :type_for_link, :type

        def type
          object.class.name.demodulize.underscore.dasherize
        end

        alias_method :format_name_for_link, :format_name

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
end
