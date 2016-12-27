# frozen_string_literal: true
require 'set'

require 'active_support/inflector'
require 'json'
require 'jsonapi-serializers'

module Sinja
  module Helpers
    module Serializers
      VALID_PAGINATION_KEYS = Set.new(%i[self first prev next last]).freeze

      def dedasherize(s=nil)
        s.to_s.underscore.send(s.is_a?(Symbol) ? :to_sym : :itself)
      end

      def dedasherize_names(*args)
        _dedasherize_names(*args).to_h
      end

      private def _dedasherize_names(hash={})
        return enum_for(__callee__, hash) unless block_given?

        hash.each do |k, v|
          yield dedasherize(k), v.is_a?(Hash) ? dedasherize_names(v) : v
        end
      end

      def deserialize_request_body
        return {} unless content?

        request.body.rewind
        JSON.parse(request.body.read, :symbolize_names=>true)
      rescue JSON::ParserError
        raise BadRequestError, 'Malformed JSON in the request body'
      end

      def serialize_response_body
        JSON.send settings._sinja.json_generator, response.body
      rescue JSON::GeneratorError
        raise BadRequestError, 'Unserializable entities in the response body'
      end

      def include_exclude!(options)
        included, default, excluded =
          params[:include],
          options.delete(:include) || [],
          options.delete(:exclude) || []

        if included.empty?
          included = default.is_a?(Array) ? default : default.split(',')

          return included if included.empty?
        end

        excluded = excluded.is_a?(Array) ? excluded : excluded.split(',')
        unless excluded.empty?
          excluded = Set.new(excluded)
          included.delete_if do |termstr|
            terms = termstr.split('.')
            terms.length.times.any? do |i|
              excluded.include?(terms.take(i.succ).join('.'))
            end
          end

          return included if included.empty?
        end

        return included unless settings._resource_config

        # Walk the tree and try to exclude based on fetch and pluck permissions
        included.keep_if do |termstr|
          catch :keep? do
            *terms, last_term = termstr.split('.')

            # Start cursor at root of current resource
            config = settings._resource_config
            terms.each do |term|
              # Move cursor through each term, avoiding the default proc,
              # halting if no roles found, i.e. client asked to include
              # something that Sinja doesn't know about
              throw :keep?, true unless config =
                settings._sinja.resource_config.fetch(term.pluralize.to_sym, nil)
            end

            throw :keep?, true unless roles =
              config.dig(:has_many, last_term.pluralize.to_sym, :fetch, :roles) ||
              config.dig(:has_one, last_term.singularize.to_sym, :pluck, :roles)

            throw :keep?, roles && (roles.empty? || roles.intersect?(memoized_role))
          end
        end
      end

      def serialize_model(model=nil, options={})
        options[:is_collection] = false
        options[:skip_collection_check] = defined?(::Sequel) && model.is_a?(::Sequel::Model)
        options[:include] = include_exclude!(options)
        options[:fields] ||= params[:fields] unless params[:fields].empty?
        options = settings._sinja.serializer_opts.merge(options)

        ::JSONAPI::Serializer.serialize(model, options)
      rescue ::JSONAPI::Serializer::InvalidIncludeError=>e
        raise BadRequestError, e
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

      def serialize_models(models=[], options={}, pagination=nil)
        options[:is_collection] = true
        options[:include] = include_exclude!(options)
        options[:fields] ||= params[:fields] unless params[:fields].empty?
        options = settings._sinja.serializer_opts.merge(options)

        if pagination
          # Whitelist pagination keys and dasherize query parameter names
          pagination = VALID_PAGINATION_KEYS
            .select(&pagination.method(:key?))
            .map! do |outer_key|
              [outer_key, pagination[outer_key].map do |inner_key, value|
                [inner_key.to_s.dasherize.to_sym, value]
              end.to_h]
            end.to_h

          options[:meta] ||= {}
          options[:meta][:pagination] = pagination

          options[:links] ||= {}
          options[:links][:self] = request.url unless pagination.key?(:self)

          base_query = Rack::Utils.build_nested_query \
            env['rack.request.query_hash'].dup.tap { |h| h.delete('page') }

          self_link, join_char =
            if base_query.empty?
              [request.path, ??]
            else
              ["#{request.path}?#{base_query}", ?&]
            end

          options[:links].merge!(pagination.map do |key, value|
            [key, [self_link,
              Rack::Utils.build_nested_query(:page=>value)].join(join_char)]
          end.to_h)
        end

        ::JSONAPI::Serializer.serialize(Array(models), options)
      rescue ::JSONAPI::Serializer::InvalidIncludeError=>e
        raise BadRequestError, e
      end

      def serialize_models?(models=[], options={}, pagination=nil)
        if Array(models).any?
          body serialize_models(models, options, pagination)
        elsif options.key?(:meta)
          body serialize_models([], :meta=>options[:meta])
        else
          status 204
        end
      end

      def serialize_linkage(model, rel, options={})
        options[:is_collection] = false
        options[:skip_collection_check] = defined?(::Sequel::Model) && model.is_a?(::Sequel::Model)
        options[:include] = rel.to_s
        options = settings._sinja.serializer_opts.merge(options)

        # TODO: This is extremely wasteful. Refactor JAS to expose the linkage serializer?
        content = ::JSONAPI::Serializer.serialize(model, options)
        content['data']['relationships'][rel.to_s].tap do |linkage|
          %w[meta jsonapi].each do |key|
            linkage[key] = content[key] if content.key?(key)
          end
        end
      end

      def serialize_linkage?(updated=false, options={})
        body updated ? serialize_linkage(options) : serialize_model?(nil, options)
      end

      def serialize_linkages?(updated=false, options={})
        body updated ? serialize_linkage(options) : serialize_models?([], options)
      end

      def error_hash(title: nil, detail: nil, source: nil)
        [
          { id: SecureRandom.uuid }.tap do |hash|
            hash[:title] = title if title
            hash[:detail] = detail if detail
            hash[:status] = status.to_s if status
            hash[:source] = source if source
          end
        ]
      end

      def exception_title(e)
        e.respond_to?(:title) ? e.title : e.class.name.demodulize.titleize
      end

      def serialize_errors
        raise env['sinatra.error'] if env['sinatra.error'] && sideloaded?

        abody = Array(body)
        error_hashes =
          if abody.any?
            if abody.all? { |error| error.is_a?(Hash) }
              # `halt' with a hash or array of hashes
              abody.flat_map(&method(:error_hash))
            elsif not_found?
              # `not_found' or `halt 404'
              message = abody.first.to_s
              error_hash \
                :title=>'Not Found Error',
                :detail=>(message unless message == '<h1>Not Found</h1>')
            else
              # `halt'
              error_hash \
                :title=>'Unknown Error',
                :detail=>abody.first.to_s
            end
          end

        # Exception already contains formatted errors
        error_hashes ||= env['sinatra.error'].error_hashes \
          if env['sinatra.error'].respond_to?(:error_hashes)

        error_hashes ||=
          case e = env['sinatra.error']
          when UnprocessibleEntityError
            e.tuples.flat_map do |attribute, full_message|
              error_hash \
                :title=>exception_title(e),
                :detail=>full_message.to_s,
                :source=>{
                  :pointer=>(attribute ? "/data/attributes/#{attribute.to_s.dasherize}" : '/data')
                }
            end
          when Exception
            error_hash \
              :title=>exception_title(e),
              :detail=>(e.message.to_s unless e.message == e.class.name)
          else
            error_hash \
              :title=>'Unknown Error'
          end

        if block = settings._sinja.error_logger
          error_hashes.each { |h| instance_exec(h, &block) }
        end

        content_type :api_json
        JSON.send settings._sinja.json_error_generator,
          ::JSONAPI::Serializer.serialize_errors(error_hashes)
      end
    end
  end
end
