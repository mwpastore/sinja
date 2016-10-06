# frozen_string_literal: true
require 'json'
require 'jsonapi-serializers'
require 'sinatra/base'
require 'sinatra/jsonapi/helpers'

module Sinatra
  module JSONAPI
    def self.registered(app)
      app.disable :protection
      app.disable :static

      app.mime_type :api_json, 'application/vnd.api+json'

      app.helpers Helpers

      app.error 400...600, nil do
        hash = error_hash(normalized_error)
        logger.error('jsonapi') { hash }
        content_type :api_json
        JSON.fast_generate ::JSONAPI::Serializer.serialize_errors [hash]
      end

      app.before do
        halt 406 unless request.preferred_type.to_s == mime_type(:api_json)
        halt 415 unless request.media_type == mime_type(:api_json)
        halt 415 if request.media_type_params.keys.any? { |k| k != 'charset' }
      end
    end

    def self.extended(base)
      def base.route(*args, **opts)
        opts[:provides] ||= :api_json

        super
      end
    end
  end

  register JSONAPI
end
