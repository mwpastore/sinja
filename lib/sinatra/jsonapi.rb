# frozen_string_literal: true
require 'set'
require 'sinatra/base'
require 'sinatra/namespace'

require 'sinja'
require 'sinatra/jsonapi/config'
require 'sinatra/jsonapi/helpers/serializers'
require 'sinatra/jsonapi/resource'
require 'sinatra/jsonapi/version'

module Sinatra::JSONAPI
  def resource(res, konst=nil, &block)
    sinja_config.resource_roles[res] # trigger default proc

    namespace "/#{res.to_s.tr('_', '-')}" do
      define_singleton_method(:can) do |action, roles|
        sinja_config.resource_roles[res].merge!(action=>roles)
      end

      helpers do
        define_method(:can?) do |*args|
          super(res, *args)
        end
      end

      register Resource

      instance_eval(&(konst || block))
    end
  end

  def sinja
    yield sinja_config
  end

  alias_method :configure_jsonapi, :sinja
  def freeze_jsonapi!
    sinja(&:freeze)
  end

  %i[role transaction].each do |helper|
    define_method(helper) do |&block|
      # capture the passed block as an instance method (i.e. a helper)
      define_method(helper, &block)
    end
  end

  def self.registered(app)
    app.register Sinatra::Namespace

    app.disable :protection, :static
    app.set :show_exceptions, :after_handler
    app.set :sinja_config, Sinatra::JSONAPI::Config.new

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

    app.helpers Helpers::Serializers do
      def can?(resource_name, action)
        roles = settings.sinja_config.resource_roles[resource_name][action]
        roles.nil? || roles.empty? || Set[*role].intersect?(roles)
      end

      def data
        @data ||= deserialized_request_body[:data]
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

    app.before do
      halt 406 unless request.preferred_type.entry == MIME_TYPE
      halt 415 unless request.media_type == MIME_TYPE
      halt 415 if request.media_type_params.keys.any? { |k| k != 'charset' }

      normalize_params!
    end

    app.after do
      body serialized_response_body if response.ok?
    end

    app.error 400...600, nil do
      serialized_error
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

Sinatra.register(Sinatra::JSONAPI)
