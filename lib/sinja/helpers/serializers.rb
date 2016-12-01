# frozen_string_literal: true
require 'active_support/inflector'
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
        return enum_for(__callee__, hash) unless block_given?

        hash.each do |k, v|
          yield dedasherize(k), Hash === v ? dedasherize_names(v) : v
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
        client, default, excluded =
          params[:include],
          options.delete(:include) || [],
          options.delete(:exclude) || []

        included = Array === client ? client : client.split(',')
        if included.empty?
          included = Array === default ? default : default.split(',')
        end

        return included if included.empty?

        excluded = Array === excluded ? excluded : excluded.split(',')
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

        return included unless settings._resource_roles

        # Walk the tree and try to exclude based on fetch and pluck permissions
        included.keep_if do |termstr|
          # Start cursor at root of current resource
          roles = settings._resource_roles

          termstr.split('.').all? do |term|
            break true unless roles

            rel_roles =
              roles.dig(:has_many, term.to_sym, :fetch) ||
              roles.dig(:has_one, term.to_sym, :pluck)

            # Move cursor ahead for next iteration (if necessary), avoiding default proc
            roles = settings._sinja.resource_roles.fetch(term.pluralize.to_sym, nil)

            rel_roles && (rel_roles.empty? || rel_roles === memoized_role)
          end
        end
      end

      def serialize_model(model=nil, options={})
        options[:is_collection] = false
        options[:skip_collection_check] = defined?(::Sequel) && ::Sequel::Model === model
        options[:include] = include_exclude!(options)
        options[:fields] ||= params[:fields] unless params[:fields].empty?

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
        options[:include] = include_exclude!(options)
        options[:fields] ||= params[:fields] unless params[:fields].empty?

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

      def serialize_linkage(model, rel_path, options={})
        options[:is_collection] = false
        options[:skip_collection_check] = defined?(::Sequel) && ::Sequel::Model === model
        options[:include] = rel_path.to_s

        content = ::JSONAPI::Serializer.serialize model,
          settings._sinja.serializer_opts.merge(options)

        # TODO: This is extremely wasteful. Refactor JAS to expose the linkage serializer?
        content['data']['relationships'][rel_path.to_s].tap do |linkage|
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

      def serialize_errors(&block)
        raise env['sinatra.error'] if env['sinatra.error'] && sideloaded?

        error_hashes =
          if [*body].any?
            if [*body].all? { |error| Hash === error }
              # `halt' with a hash or array of hashes
              [*body].flat_map { |error| error_hash(error) }
            elsif not_found?
              # `not_found' or `halt 404'
              message = [*body].first.to_s
              error_hash \
                :title=>'Not Found Error',
                :detail=>(message unless message == '<h1>Not Found</h1>')
            else
              # `halt'
              error_hash \
                :title=>'Unknown Error',
                :detail=>[*body].first.to_s
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
                :title=>e.title,
                :detail=>full_message.to_s,
                :source=>{
                  :pointer=>(attribute ? "/data/attributes/#{attribute.to_s.dasherize}" : '/data')
                }
            end
          when Exception
            title =
              if e.respond_to?(:title)
                e.title
              else
                e.class.name.split('::').last.split(/(?=[[:upper:]])/).join(' ')
              end

            error_hash \
              :title=>title,
              :detail=>(e.message.to_s unless e.message == e.class.name)
          end

        # Ensure we don't send an empty errors collection
        error_hashes ||= error_hash(:title=>'Unknown Error')

        error_hashes.each { |eh| instance_exec(eh, &block) } if block

        JSON.send settings._sinja.json_error_generator,
          ::JSONAPI::Serializer.serialize_errors(error_hashes)
      end
    end
  end
end
