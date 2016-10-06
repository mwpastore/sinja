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

        def data
          deserialize_request_body[:data]
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

      def role(&block)
        helpers { define_method(__callee__, &block) }
      end

      def self.registered(app)
        app.register JSONAPI

        app.set :actions do |*actions|
          condition do
            actions.all? do |action|
              roles = settings.action_roles[action]
              halt 403 unless roles.empty? || Set[*role].intersect?(roles)
              halt 405 unless respond_to?(action)
              true
            end
          end
        end

        app.helpers Helpers

        app.before do
          normalize_params!
        end

        app.after do
          pass if env['jsonapi.bypass']

          body serialize_response_body if response.ok?
        end
      end
    end
  end
end
