# frozen_string_literal: true
require 'set'
require 'sinatra/jsonapi'

module Sinatra
  module JSONAPI
    module AbstractResource
      module Helpers
        def normalize_params!
          # TODO: halt 400 if other params, or params not implemented?
          {
            :filter=>{},
            :fields=>{},
            :page=>{},
            :include=>[]
          }.each { |k, v| params[k] ||= v }
        end

        def can?(_)
          true
        end

        def data
          @data ||= deserialize_request_body[:data]
        end

        def attributes
          return enum_for(__callee__) unless block_given?
          data.fetch(:attributes, {})
        end

        def relationships
          return enum_for(__callee__) unless block_given?
          data.fetch(:relationships, {})
        end

        def serialize_model(model=nil, options={})
          options[:is_collection] = false
          options[:skip_collection_check] = defined?(Sequel)

          ::JSONAPI::Serializer.serialize(model, options)
        end

        def serialize_models(models=[], options={})
          options[:is_collection] = true

          ::JSONAPI::Serializer.serialize([*models], options)
        end
      end

      def self.registered(app)
        app.register JSONAPI

        app.helpers Helpers

        app.before do
          normalize_params!
        end

        app.after do
          pass if env['SJA']['nested']

          body serialize_response_body if response.ok?
        end
      end
    end
  end
end
