# frozen_string_literal: true
require 'active_support/inflector'
require 'mustermann'
require 'sinatra/base'
require 'sinatra/namespace'

require 'set'
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

    resource_name = resource_name.to_s
      .pluralize
      .dasherize
      .to_sym

    # trigger default procs
    config = _sinja.resource_config[resource_name]

    namespace "/#{resource_name}" do
      define_singleton_method(:_resource_config) { config }
      define_singleton_method(:resource_config) { config[:resource] }

      helpers do
        %i[can? sanity_check! sideload?].each do |meth|
          define_method(meth) do |*args|
            super(resource_name, *args)
          end
        end
      end

      before %r{/(?<id>[^/]+)(?:/.*)?} do |id|
        self.resource =
          if env.key?('sinja.resource')
            env['sinja.resource']
          elsif respond_to?(:find)
            find(id)
          end

        raise NotFoundError, "Resource '#{id}' not found" unless resource
      end

      register Resource

      instance_eval(&block)
    end
  end

  alias_method :resources, :resource

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
    app.register Mustermann if Sinatra::VERSION[/^\d+/].to_i < 2
    app.register Sinatra::Namespace

    app.disable :protection, :show_exceptions, :static
    app.set :_sinja, Sinja::Config.new
    app.set :_resource_config, nil # dummy value overridden in each resource

    app.set :actions do |*actions|
      condition do
        actions.each do |action|
          raise ForbiddenError, 'You are not authorized to perform this action' \
            unless can?(action) || sideload?(action)
          raise MethodNotAllowedError, 'Action or method not implemented or supported' \
            unless respond_to?(action)
        end

        true
      end
    end

    app.set :qcapture do |*index|
      condition do
        @qcaptures ||= []
        index.to_h.all? do |key, subkeys|
          params.key?(key.to_s) && [*subkeys].all? do |subkey|
            @qcaptures << params[key.to_s].delete(subkey.to_s) \
              if params[key.to_s].key?(subkey.to_s)
          end
        end
      end
    end

    app.set :qparams do |*allow_params|
      allow_params = allow_params.to_set

      abort "Unexpected query parameter(s) in route definiton" \
        unless allow_params.subset?(settings._sinja.query_params.keys.to_set)

      condition do
        params.each do |key, value|
          key = key.to_sym

          next if settings._sinja.query_params[key].nil?

          raise BadRequestError, "`#{key}' query parameter not allowed" \
            unless allow_params.include?(key) || value.empty?

          if Array === settings._sinja.query_params[key] && String === value
            value = (params[key.to_s] = value.split(','))
          elsif !(settings._sinja.query_params[key].class === value)
            raise BadRequestError, "`#{key}' query parameter malformed"
          end
        end

        settings._sinja.query_params.each do |key, value|
          next if value.nil?

          key = key.to_s

          if respond_to?("normalize_#{key}_params")
            params[key] = send("normalize_#{key}_params")
          else
            params[key] ||= value
          end
        end

        true
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

      if method_defined?(:bad_request?)
        # This screws up our error-handling logic in Sinatra 2.0, so monkeypatch it.
        def bad_request?
          false
        end
      end

      def can?(resource_name, action, rel_type=nil, rel=nil)
        config = settings._sinja.resource_config[resource_name]
        config = rel_type && rel ? config[rel_type][rel] : config[:resource]
        roles = config&.dig(action, :roles)

        roles.nil? || roles.empty? || roles === memoized_role
      end

      def content?
        request.body.respond_to?(:size) && request.body.size > 0
      end

      def data
        @data ||= {}
        @data[request.path] ||= begin
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

      def sideload?(resource_name, child)
        return unless sideloaded?
        parent = env['sinja.passthru'].to_sym
        settings.resource_config[child][:sideload_on]&.include?(parent) && can?(parent)
      end

      def sideloaded?
        env.key?('sinja.passthru')
      end

      def role
        nil
      end

      def role?(*roles)
        Roles[*roles] === memoized_role
      end

      def sanity_check!(resource_name, id=nil)
        raise ConflictError, 'Resource type in payload does not match endpoint' \
          if data[:type].to_sym != resource_name

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

      content_type :api_json
    end

    app.after do
      body serialize_response_body if response.ok? || response.created?
    end

    app.error 400...600 do
      serialize_errors(&settings._sinja.error_logger)
    end

    app.error StandardError do
      env['sinatra.error'].tap do |e|
        boom =
          if settings._sinja.not_found_exceptions.any? { |c| c === e }
            NotFoundError.new(e.message) unless NotFoundError === e
          elsif settings._sinja.conflict_exceptions.any? { |c| c === e }
            ConflictError.new(e.message) unless ConflictError === e
          elsif settings._sinja.validation_exceptions.any? { |c| c === e }
            UnprocessibleEntityError.new(settings._sinja.validation_formatter.(e)) unless UnprocessibleEntityError === e
          end

        handle_exception!(boom) if boom # re-throw the re-packaged exception
      end

      serialize_errors(&settings._sinja.error_logger)
    end
  end

  def self.extended(base)
    def base.route(*, **opts)
      opts[:qparams] ||= []

      super
    end
  end
end
