# frozen_string_literal: true
require 'json'
require 'jsonapi-serializers'
require 'sinatra/base'

module Sinatra
  module JSONAPI
    module Helpers
      def deserialize_request_body
        return {} unless request.body.respond_to?(:size) && request.body.size > 0

        request.body.rewind
        JSON.parse(request.body.read, :symbolize_names=>true)
      rescue JSON::ParserError
        halt 400, 'Malformed JSON in the request body'
      end

      def serialize_response_body
        JSON.generate(response.body)
      rescue JSON::GeneratorError
        halt 400, 'Unserializable entities in the response body'
      end

      def normalized_error
        return body if body.is_a?(Hash)

        if not_found? && detail = [*body].first
          title = 'Not Found'
          detail = nil if detail == '<h1>Not Found</h1>'
        elsif env.key?('sinatra.error') && detail = env['sinatra.error'].message
          title = 'Unknown Error'
        elsif detail = [*body].first
        end

        { title: title, detail: detail }
      end

      def error_hash(title: nil, detail: nil, source: nil)
        { id: SecureRandom.uuid }.tap do |hash|
          hash[:title] = title if title
          hash[:detail] = detail if detail
          hash[:status] = status.to_s if status
          hash[:source] = source if source
        end
      end
    end

    def self.registered(app)
      app.disable :protection
      app.disable :static

      app.mime_type :api_json, 'application/vnd.api+json'

      app.helpers Helpers

      app.error 400...600, nil do
        pass if env['jsonapi.bypass']

        hash = error_hash(normalized_error)
        logger.error('jsonapi') { hash }
        content_type :api_json
        JSON.fast_generate ::JSONAPI::Serializer.serialize_errors [hash]
      end

      app.before do
        pass if env['jsonapi.resource']

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
