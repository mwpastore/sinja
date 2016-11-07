# frozen_string_literal: true
require 'set'
require 'sinatra/base'
require 'sinatra/namespace'

require 'sinja'
require 'sinja/version'

require 'sinatra/jsonapi/config'
require 'sinatra/jsonapi/helpers/serializers'
require 'sinatra/jsonapi/resource'

module Sinatra::JSONAPI
  def resource(resource_name, konst=nil, &block)
    abort "Must supply proc constant or block for `resource'" \
      unless block = konst and konst.is_a?(Proc) or block

    sinja_config.resource_roles[resource_name.to_sym] # trigger default proc

    namespace "/#{resource_name.to_s.tr('_', '-')}" do
      define_singleton_method(:can) do |action, roles|
        sinja_config.resource_roles[resource_name.to_sym].merge!(action=>roles)
      end

      helpers do
        define_method(:can?) do |*args|
          super(resource_name.to_sym, *args)
        end
      end

      register Resource

      instance_eval(&block)
    end
  end

  def sinja
    if block_given?
      yield sinja_config
    else
      sinja_config
    end
  end

  alias_method :configure_jsonapi, :sinja
  def freeze_jsonapi
    sinja_config.freeze
  end

  def self.registered(app)
    app.register Sinatra::Namespace

    app.disable :protection, :static
    app.set :sinja_config, Sinatra::JSONAPI::Config.new
    app.configure(:development) do |c|
      c.set :show_exceptions, :after_handler
    end

    app.set :actions do |*actions|
      condition do
        actions.each do |action|
          halt 403, 'You are not authorized to perform this action' unless can?(action)
          halt 405, 'Action or method not implemented or supported' unless respond_to?(action)
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
          :fields=>{}, # passthru
          :include=>[], # passthru
          :filter=>{},
          :page=>{},
          :sort=>''
        }.each { |k, v| params[k] ||= v }
      end

      def role
        nil
      end

      def transaction
        yield
      end
    end

    app.before do
      halt 406 unless request.preferred_type.entry == MIME_TYPE
      halt 415 unless request.media_type == MIME_TYPE
      halt 415 if request.media_type_params.keys.any? { |k| k != 'charset' }

      content_type :api_json

      normalize_params!
    end

    app.after do
      body serialized_response_body if response.ok?
    end

    app.error 400...600, nil do
      serialized_error
    end
  end
end

module Sinatra
  register JSONAPI
end
