# frozen_string_literal: true
require 'json'
require 'jsonapi-serializers'
require 'set'

module Sinja
  module Helpers
    module Serializers
      module_function def dasherize(s=nil)
        s.to_s.tr('_', '-').send(Symbol === s ? :to_sym : :itself)
      end

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
        default, extra = options.delete(:include), params[:include]

        default =
          if Array === default then default
          elsif default then default.split(',')
          else []
          end

        extra =
          if Array === extra then extra
          elsif extra then extra.split(',')
          else []
          end

        included, excluded = default | extra, options.delete(:exclude)

        return included unless included.any? && excluded

        excluded = Set.new(excluded.is_a?(Array) ? excluded : excluded.split(','))

        included.delete_if do |termstr|
          terms = termstr.split('.')
          terms.length.times.any? do |i|
            excluded.include?(terms.take(i.succ).join('.'))
          end
        end
      end

      def serialize_model(model=nil, options={})
        options[:is_collection] = false
        options[:skip_collection_check] = defined?(::Sequel) && model.is_a?(::Sequel::Model)
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
                  :pointer=>(attribute ? "/data/attributes/#{dasherize(attribute)}" : '/data')
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
