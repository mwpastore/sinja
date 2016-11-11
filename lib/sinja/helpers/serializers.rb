# frozen_string_literal: true
require 'json'
require 'jsonapi-serializers'
require 'set'

module Sinja
  module Helpers
    module Serializers
      def dedasherize(s=nil)
        s.to_s.tr('-', '_').send(Symbol === s ? :to_sym : :itself)
      end

      def dedasherize_names(*args)
        _dedasherize_names(*args).to_h
      end

      private def _dedasherize_names(hash={})
        return enum_for(__callee__) unless block_given?

        hash.each do |k, v|
          yield dedasherize(k), Hash === v ? dedasherize_names(v) : v
        end
      end

      def deserialized_request_body
        return {} unless content?

        request.body.rewind
        JSON.parse(request.body.read, :symbolize_names=>true)
      rescue JSON::ParserError
        halt 400, 'Malformed JSON in the request body'
      end

      def serialized_response_body
        JSON.send settings._sinja.json_generator, response.body
      rescue JSON::GeneratorError
        halt 400, 'Unserializable entities in the response body'
      end

      def exclude!(options)
        included, excluded = options.delete(:include), options.delete(:exclude)

        included = Set.new(included.is_a?(Array) ? included : included.split(','))
        excluded = Set.new(excluded.is_a?(Array) ? excluded : excluded.split(','))

        included.delete_if do |termstr|
          terms = termstr.split('.')
          terms.length.times.any? do |i|
            excluded.include?(terms.take(i.succ).join('.'))
          end
        end

        options[:include] = included.to_a unless included.empty?
      end

      def serialize_model(model=nil, options={})
        options[:is_collection] = false
        options[:skip_collection_check] = defined?(::Sequel) && model.is_a?(::Sequel::Model)
        # TODO: This should allow a default include, take the param value if
        # present, and support disabling passthru.
        options[:include] ||= params[:include] unless params[:include].empty?
        options[:fields] ||= params[:fields] unless params[:fields].empty?

        exclude!(options) if options[:include] && options[:exclude]

        ::JSONAPI::Serializer.serialize model,
          settings._sinja.serializer_opts.merge(options)
      end

      def serialize_model?(model=nil, options={})
        if model
          body serialize_model(model, options)
        elsif options.key?(:meta)
          body serialize_model(nil, :meta=>options[:meta])
        else
          status 204
        end
      end

      def serialize_models(models=[], options={})
        options[:is_collection] = true
        # TODO: This should allow a default include, take the param value if
        # present, and support disabling passthru.
        options[:include] ||= params[:include] unless params[:include].empty?
        options[:fields] ||= params[:fields] unless params[:fields].empty?

        exclude!(options) if options[:include] && options[:exclude]

        ::JSONAPI::Serializer.serialize [*models],
          settings._sinja.serializer_opts.merge(options)
      end

      def serialize_models?(models=[], options={})
        if [*models].any?
          body serialize_models(models, options)
        elsif options.key?(:meta)
          body serialize_models([], :meta=>options[:meta])
        else
          status 204
        end
      end

      def serialize_linkage(options={})
        options = settings._sinja.serializer_opts.merge(options)
        linkage.tap do |c|
          c[:meta] = options[:meta] if options.key?(:meta)
          c[:jsonapi] = options[:jsonapi] if options.key?(:jsonapi)
        end
      end

      def serialize_linkage?(updated=false, options={})
        body updated ? serialize_linkage(options) : serialize_model?(nil, options)
      end

      def serialize_linkages?(updated=false, options={})
        body updated ? serialize_linkage(options) : serialize_models?([], options)
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

        { :title=>title, :detail=>detail }
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
        logger.error(settings._sinja.logger_progname) { hash }
        JSON.send settings._sinja.json_error_generator,
          ::JSONAPI::Serializer.serialize_errors([hash])
      end
    end
  end
end
