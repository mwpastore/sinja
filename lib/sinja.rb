# frozen_string_literal: true
require 'mustermann'
require 'sinatra/base'
require 'sinatra/namespace'

require 'sinja/config'
require 'sinja/errors'
require 'sinja/helpers/serializers'
require 'sinja/resource'
require 'sinja/version'

module Sinja
  MIME_TYPE = 'application/vnd.api+json'
  ERROR_CODES = [
    BadRequestError,
    ForbiddenError,
    NotFoundError,
    MethodNotAllowedError,
    NotAcceptibleError,
    ConflictError,
    UnsupportedTypeError
  ].map! { |c| [c.new.http_status, c] }.to_h.tap do |h|
    h[422] = UnprocessibleEntityError
  end.freeze

  def resource(resource_name, konst=nil, &block)
    abort "Must supply proc constant or block for `resource'" \
      unless block = (konst if konst.is_a?(Proc)) || block

    # trigger default procs
    _sinja.resource_roles[resource_name.to_sym]
    _sinja.resource_sideload[resource_name.to_sym]

    namespace "/#{Helpers::Serializers.dasherize(resource_name.to_s)}" do
      define_singleton_method(:resource_roles) do |action, roles|
        _sinja.resource_roles[resource_name.to_sym].merge!(action=>roles)
      end

      define_singleton_method(:resource_sideload) do |child, parents|
        _sinja.resource_sideload[resource_name.to_sym].merge!(child=>parents)
      end

      helpers do
        define_method(:can?) do |*args|
          super(resource_name.to_sym, *args)
        end

        define_method(:sideload?) do |*args|
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
    app.register Mustermann unless app.extensions.include?(Mustermann)
    app.register Sinatra::Namespace

    app.disable :protection, :show_exceptions, :static
    app.set :_sinja, Sinja::Config.new

    app.set :actions do |*actions|
      condition do
        actions.each do |action|
          raise ForbiddenError, 'You are not authorized to perform this action' \
            unless action == :find || can?(action) || sideload?(action)
          raise MethodNotAllowedError, 'Action or method not implemented or supported' \
            unless respond_to?(action)
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
        roles.nil? || roles.empty? || roles === memoized_role
      end

      def content?
        request.body.respond_to?(:size) && request.body.size > 0
      end

      def data
        @data ||= begin
          deserialize_request_body.fetch(:data)
        rescue NoMethodError, KeyError
          raise BadRequestError, 'Malformed JSON:API request payload'
        end
      end

      def halt(code, body=nil)
        if exception_class = ERROR_CODES[code]
          raise exception_class, body
        elsif (400...600).include?(code.to_i)
          raise HttpError.new(code.to_i, body)
        else
          super
        end
      end

      def memoized_role
        @role ||= role
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

      def sideload?(resource_name, child)
        return unless sideloaded?
        parent = env.fetch('sinja.passthru', 'unknown').to_sym
        settings._sinja.resource_sideload[resource_name][child].
          include?(parent) && can?(parent)
      end

      def sideloaded?
        env.key?('sinja.passthru')
      end

      def role
        nil
      end

      def sanity_check!(id=nil)
        raise ConflictError, 'Resource type in payload does not match endpoint' \
          if data[:type] != request.path.split('/').last # TODO?

        raise ConflictError, 'Resource ID in payload does not match endpoint' \
          if id && data[:id].to_s != id.to_s
      end

      def transaction
        yield
      end
    end

    app.before do
      unless sideloaded?
        raise NotAcceptibleError unless request.preferred_type.entry == MIME_TYPE
        raise UnsupportedTypeError if content? && (
          request.media_type != MIME_TYPE || request.media_type_params.keys.any? { |k| k != 'charset' }
        )
      end

      normalize_params!

      content_type :api_json
    end

    app.after do
      body serialize_response_body if response.ok?
    end

    app.not_found do
      serialize_errors(&settings._sinja.error_logger)
    end

    # TODO: Can/should we serialize other types of Exceptions? Catch-all?
    app.error StandardError, 400...600, nil do
      serialize_errors(&settings._sinja.error_logger)
    end
  end
end
