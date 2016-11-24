# frozen_string_literal: true
require 'sinatra/base'
require 'sinatra/namespace'

require 'sinja/config'
require 'sinja/helpers/serializers'
require 'sinja/resource'
require 'sinja/version'

module Sinja
  MIME_TYPE = 'application/vnd.api+json'

  SinjaError = Class.new(StandardError)
  ActionHelperError = Class.new(SinjaError)

  def resource(resource_name, konst=nil, &block)
    abort "Must supply proc constant or block for `resource'" \
      unless block = (konst if konst.is_a?(Proc)) || block

    _sinja.resource_roles[resource_name.to_sym] # trigger default proc

    namespace "/#{resource_name.to_s.tr('_', '-')}" do
      define_singleton_method(:can) do |action, roles|
        _sinja.resource_roles[resource_name.to_sym].merge!(action=>roles)
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
      yield _sinja
    else
      _sinja
    end
  end

  alias_method :configure_jsonapi, :sinja
  def freeze_jsonapi
    _sinja.freeze
  end

  def self.registered(app)
    app.register Sinatra::Namespace

    app.disable :protection, :static
    app.set :_sinja, Sinja::Config.new
    app.configure(:development) do |c|
      c.set :show_exceptions, :after_handler
    end

    app.set :actions do |*actions|
      condition do
        actions.each do |action|
          halt 403, 'You are not authorized to perform this action' unless action == :find || can?(action) ||
            Set[:graft, :merge].include?(action) && passthru? { |parent| can?(parent) }
          halt 405, 'Action or method not implemented or supported' unless respond_to?(action)
        end
        true
      end
    end

    app.set :pfilters do |*pfilters|
      condition do
        pfilters.all? do |pfilter|
          params.key?('filter') && params['filter'].key?(pfilter.to_s)
        end
      end
    end

    app.set :nullif do |nullish|
      condition { nullish.(data) }
    end

    app.mime_type :api_json, MIME_TYPE

    app.helpers Helpers::Serializers do
      def allow(h={})
        s = Set.new
        h.each do |method, actions|
          s << method if [*actions].all? { |action| respond_to?(action) }
        end
        headers 'Allow'=>s.map(&:upcase).join(',')
      end

      def attributes
        dedasherize_names(data.fetch(:attributes, {}))
      end

      def can?(resource_name, action)
        roles = settings._sinja.resource_roles[resource_name][action]
        roles.nil? || roles.empty? || roles === role
      end

      def content?
        request.body.respond_to?(:size) && request.body.size > 0
      end

      def data
        @data ||= begin
          deserialize_request_body.fetch(:data)
        rescue NoMethodError, KeyError
          halt 400, 'Malformed JSON:API request payload'
        end
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

      def passthru?
        env.key?('sinja.passthru') && (
          !block_given? || yield(env['sinja.passthru'].to_sym)
        )
      end

      def role
        nil
      end

      def sanity_check!(id=nil)
        halt 409, 'Resource type in payload does not match endpoint' \
          if data[:type] != request.path.split('/').last # TODO

        halt 409, 'Resource ID in payload does not match endpoint' \
          if id && data[:id].to_s != id.to_s
      end

      def transaction
        yield
      end
    end

    app.before do
      unless passthru?
        halt 406 unless request.preferred_type.entry == MIME_TYPE

        if content?
          halt 415 unless request.media_type == MIME_TYPE
          halt 415 if request.media_type_params.keys.any? { |k| k != 'charset' }
        end
      end

      normalize_params!

      content_type :api_json
    end

    app.after do
      body serialize_response_body if response.ok?
    end

    app.error 400...600, nil do
      serialize_errors
    end
  end
end
