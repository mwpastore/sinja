# frozen_string_literal: true
require 'json'
require 'jsonapi-serializers'

module Sinatra::JSONAPI
  module Helpers
    module Serializers
      def deserialized_request_body
        return {} unless request.body.respond_to?(:size) && request.body.size > 0

        request.body.rewind
        JSON.parse(request.body.read, :symbolize_names=>true)
      rescue JSON::ParserError
        halt 400, 'Malformed JSON in the request body'
      end

      def serialized_response_body
        JSON.generate(response.body)
      rescue JSON::GeneratorError
        halt 400, 'Unserializable entities in the response body'
      end

      def serialize_model!(model=nil, options={})
        options[:is_collection] = false
        options[:skip_collection_check] = defined?(Sequel) && model.is_a?(Sequel::Model)
        options[:include] ||= params[:include] unless params[:include].empty? # TODO

        ::JSONAPI::Serializer.serialize model,
          settings.sinja_config.serializer_opts.merge(options)
      end

      def serialize_model?(model=nil, options={})
        if model
          serialize_model!(model, options)
        elsif options.key?(:meta)
          serialize_model!(nil, :meta=>options[:meta])
        else
          204
        end
      end

      def serialize_models!(models=[], options={})
        options[:is_collection] = true
        options[:include] ||= params[:include] unless params[:include].empty? # TODO

        ::JSONAPI::Serializer.serialize [*models],
          settings.sinja_config.serializer_opts.merge(options)
      end

      def serialize_models?(models=[], options={})
        if [*models].any?
          serialize_models!(models, options)
        elsif options.key?(:meta)
          serialize_models!([], :meta=>options[:meta])
        else
          204
        end
      end

      def normalized_error
        return body if body.is_a?(Hash)

        if not_found? && detail = [*body].first
          title = 'Not Found'
          detail = nil if detail == '<h1>Not Found</h1>'
        elsif env.key?('sinatra.error')
          title = 'Unknown Error'
          detail = env['sinatra.error'].message
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

      def serialized_error
        hash = error_hash(normalized_error)
        logger.error(settings.sinja_config.logger_progname) { hash }
        content_type :api_json
        JSON.fast_generate ::JSONAPI::Serializer.serialize_errors [hash]
      end
    end
  end
end
