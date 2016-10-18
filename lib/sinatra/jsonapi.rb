# frozen_string_literal: true
require 'json'
require 'jsonapi-serializers'
require 'set'
require 'sinatra/base'
require 'sinatra/jsonapi/resource'
require 'sinatra/namespace'

module Sinatra
  module JSONAPI
    MIME_TYPE = 'application/vnd.api+json'

    module RequestHelpers
      def can?(action)
        roles = settings.sinja.resource_roles[@resource_name][action]
        roles.nil? || roles.empty? || Set[*role].intersect?(roles)
      end

      def data
        @data ||= deserialized_request_body[:data]
      end

      def deserialized_request_body
        return {} unless request.body.respond_to?(:size) && request.body.size > 0

        request.body.rewind
        JSON.parse(request.body.read, :symbolize_names=>true)
      rescue JSON::ParserError
        halt 400, 'Malformed JSON in the request body'
      end

      def normalize_params!
        # TODO: halt 400 if other params, or params not implemented?
        {
          :filter=>{},
          :fields=>{},
          :page=>{},
          :include=>[]
        }.each { |k, v| params[k] ||= v }
      end
    end

    module ResponseHelpers
      def serialize_model!(model=nil, options={})
        options[:is_collection] = false
        options[:skip_collection_check] = defined?(Sequel) && model.is_a?(Sequel::Model)
        options[:include] ||= params[:include] unless params[:include].empty? # TODO

        ::JSONAPI::Serializer.serialize model,
          settings.sinja.serializer_opts.merge(options)
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
          settings.sinja.serializer_opts.merge(options)
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

      def serialized_response_body
        JSON.generate(response.body)
      rescue JSON::GeneratorError
        halt 400, 'Unserializable entities in the response body'
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
    end

    def resource(res, konst=nil, &block)
      namespace "/#{res.to_s.tr('_', '-')}" do
        @resource_name = res
        register Resource
        instance_eval(&(konst || block))
      end
    end

    def configure_jsonapi
      yield sinja
    end

    def freeze_jsonapi!
      sinja.freeze!
    end

    %i[role transaction].each do |helper|
      define_method(helper) do |&block|
        helpers { define_method(helper, &block) }
      end
    end

    def self.registered(app)
      app.register Namespace

      app.disable :protection # TODO
      app.disable :static

      app.set :show_exceptions, :after_handler
      app.set :sinja, Sinatra::JSONAPI::Config.new

      app.set :actions do |*actions|
        condition do
          actions.each do |action|
            halt 403 unless can?(action)
            halt 405 unless respond_to?(action)
          end
          true
        end
      end

      app.set :nullif do |nullish|
        condition { nullish.(data) }
      end

      app.mime_type :api_json, MIME_TYPE

      app.helpers RequestHelpers, ResponseHelpers

      app.error 400...600, nil do
        hash = error_hash(normalized_error)
        logger.error(settings.sinja.progname) { hash }
        content_type :api_json
        JSON.fast_generate ::JSONAPI::Serializer.serialize_errors [hash]
      end

      app.before do
        halt 406 unless request.preferred_type.entry == MIME_TYPE
        halt 415 unless request.media_type == MIME_TYPE
        halt 415 if request.media_type_params.keys.any? { |k| k != 'charset' }

        normalize_params!
      end

      app.after do
        body serialized_response_body if response.ok?
      end

      app.role { nil }
      app.transaction { yield }
    end

    def self.extended(base)
      def base.route(*, **opts)
        opts[:provides] ||= :api_json

        super
      end
    end
  end

  register JSONAPI
end
