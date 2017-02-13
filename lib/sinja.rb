# frozen_string_literal: true
require 'set'

require 'active_support/inflector'
require 'mustermann'
require 'sinatra/base'
require 'sinatra/namespace'

require 'sinja/config'
require 'sinja/errors'
require 'sinja/helpers/serializers'
require 'sinja/resource'
require 'sinja/version'

module Sinja
  DEFER_CODE = 357
  MIME_TYPE = 'application/vnd.api+json'
  ERROR_CODES = ObjectSpace.each_object(Class).to_a
    .keep_if { |klass| klass < HttpError }
    .map! { |c| [(c.const_get(:HTTP_STATUS) rescue nil), c] }
    .delete_if { |a| a.first.nil? }
    .to_h.freeze

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
            unless can?(action)
          raise MethodNotAllowedError, 'Action or method not implemented or supported' \
            unless respond_to?(action)
        end

        true
      end
    end

    app.set :qcaptures do |*index|
      condition do
        @qcaptures ||= []

        index.to_h.all? do |key, subkeys|
          key = key.to_s

          params[key].is_a?(Hash) && params[key].any? && Array(subkeys).all? do |subkey|
            subkey = subkey.to_s

            # TODO: What if deleting one is successful, but not another?
            # We'll need to restore the hash to its original state.
            @qcaptures << params[key].delete(subkey) if params[key].key?(subkey)
          end.tap do |ok|
            # If us deleting key(s) causes the hash to become empty, delete it.
            params.delete(key) if ok && params[key].empty?
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

          # Ignore interal Sinatra query parameters (e.g. :captures) and any
          # "known" query parameter set to `nil' in the configurable.
          next if !env['rack.request.query_hash'].key?(key.to_s) ||
            settings._sinja.query_params.fetch(key, BasicObject).nil?

          raise BadRequestError, "`#{key}' query parameter not allowed" \
            unless allow_params.include?(key)

          next if env['sinja.normalized'] == params.object_id

          if value.instance_of?(String) && settings._sinja.query_params[key] != String
            params[key.to_s] = value.split(',')
          elsif !value.is_a?(settings._sinja.query_params[key])
            raise BadRequestError, "`#{key}' query parameter malformed"
          end
        end

        return true if env['sinja.normalized'] == params.object_id

        settings._sinja.query_params.each do |key, klass|
          next if klass.nil?

          if respond_to?("normalize_#{key}_params")
            params[key.to_s] = send("normalize_#{key}_params")
          else
            params[key.to_s] ||= klass.new
          end
        end

        # Sinatra 2.0 re-initializes `params' at namespace boundaries, but
        # Sinatra 1.4 does not, so we'll reference its object_id in the flag
        # to make sure we only re-normalize the parameters when necessary.
        env['sinja.normalized'] = params.object_id
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
          s << method if Array(actions).all?(&method(:respond_to?))
        end
        headers 'Allow'=>s.map(&:upcase).join(',')
      end

      def attributes
        dedasherize_names(data.fetch(:attributes, {}))
      end

      if method_defined?(:bad_request?)
        # This screws up our error-handling logic in Sinatra 2.0, so override it.
        # https://github.com/sinatra/sinatra/issues/1211
        # https://github.com/sinatra/sinatra/pull/1212
        def bad_request?
          false
        end
      end

      def can?(action)
        roles = settings._resource_config[:resource].fetch(action, {})[:roles]
        roles.nil? || roles.empty? || roles.intersect?(role)
      end

      def content?
        request.body.respond_to?(:size) && request.body.size > 0 || begin
          request.body.rewind
          request.body.read(1)
        end
      end

      def data
        @data ||= {}
        @data[request.path] ||= begin
          deserialize_request_body.fetch(:data)
        rescue NoMethodError, KeyError
          raise BadRequestError, 'Malformed {json:api} request payload'
        end
      end

      def normalize_filter_params
        return {} unless params[:filter]&.any?

        raise BadRequestError, "Unsupported `filter' query parameter(s)" \
          unless respond_to?(:filter)

        params[:filter].map do |k, v|
          [dedasherize(k).to_sym, v]
        end.to_h
      end

      def filter_by?(action)
        return if params[:filter].empty?

        return params[:filter] \
          if settings.resource_config[action][:filter_by].empty? ||
            params[:filter].keys.to_set.subset?(settings.resource_config[action][:filter_by])

        raise BadRequestError, "Invalid `filter' query parameter(s)"
      end

      def normalize_sort_params
        return {} unless params[:sort]&.any?

        raise BadRequestError, "Unsupported `sort' query parameter(s)" \
          unless respond_to?(:sort)

        params[:sort].map do |k|
          dir = k.sub!(/^-/, '') ? :desc : :asc
          [dedasherize(k).to_sym, dir]
        end.to_h
      end

      def sort_by?(action)
        return if params[:sort].empty?

        return params[:sort] \
          if settings.resource_config[action][:sort_by].empty? ||
            params[:sort].keys.to_set.subset?(settings.resource_config[action][:sort_by])

        raise BadRequestError, "Invalid `sort' query parameter(s)"
      end

      def normalize_page_params
        return {} unless params[:page]&.any?

        raise BadRequestError, "Unsupported `page' query parameter(s)" \
          unless respond_to?(:page)

        params[:page].map do |k, v|
          [dedasherize(k).to_sym, v]
        end.to_h
      end

      def page_using?
        return if params[:page].empty?

        return params[:page] \
          if (params[:page].keys - settings._sinja.page_using.keys).empty?

        raise BadRequestError, "Invalid `page' query parameter(s)"
      end

      def filter_sort_page?(action)
        return enum_for(__callee__, action) unless block_given?

        if filter = filter_by?(action) then yield :filter, filter end
        if sort = sort_by?(action) then yield :sort, sort end
        if page = page_using? then yield :page, page end
      end

      def filter_sort_page(collection, opts)
        collection = filter(collection, opts[:filter]) if opts.key?(:filter)
        collection = sort(collection, opts[:sort]) if opts.key?(:sort)
        collection, pagination = page(collection, opts[:page]) if opts.key?(:page)

        return respond_to?(:finalize) ? finalize(collection) : collection, pagination
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

      def sideloaded?
        env.key?('sinja.passthru')
      end

      def role
        nil
      end

      def role?(*roles)
        Roles[*roles].intersect?(role)
      end

      def sanity_check!(resource_name, id=nil)
        raise ConflictError, 'Resource type in payload does not match endpoint' \
          unless data[:type] && data[:type].to_sym == resource_name

        raise ConflictError, 'Resource ID in payload does not match endpoint' \
          unless id.nil? || data[:id] && data[:id].to_s == id.to_s
      end

      def transaction
        yield
      end
    end

    app.before do
      unless sideloaded?
        raise NotAcceptableError unless request.preferred_type.entry == MIME_TYPE
        raise UnsupportedTypeError if content? && (
          request.media_type != MIME_TYPE || request.media_type_params.keys.any? { |k| k != 'charset' }
        )
      end

      content_type :api_json
    end

    app.after do
      body serialize_response_body if response.successful?
    end

    app.not_found do
      serialize_errors
    end

    app.error 400...600 do
      serialize_errors
    end

    app.error StandardError do
      env['sinatra.error'].tap do |e|
        boom =
          if settings._sinja.not_found_exceptions.any?(&e.method(:is_a?))
            NotFoundError.new(e.message) unless e.instance_of?(NotFoundError)
          elsif settings._sinja.conflict_exceptions.any?(&e.method(:is_a?))
            ConflictError.new(e.message) unless e.instance_of?(ConflictError)
          elsif settings._sinja.validation_exceptions.any?(&e.method(:is_a?))
            UnprocessibleEntityError.new(settings._sinja.validation_formatter.(e)) unless e.instance_of?(UnprocessibleEntityError)
          end

        handle_exception!(boom) if boom # re-throw the re-packaged exception
      end

      serialize_errors
    end
  end

  def resource(resource_name, konst=nil, &block)
    abort "Must supply proc constant or block for `resource'" \
      unless block = (konst if konst.instance_of?(Proc)) || block

    warn "DEPRECATED: Pass a block to `resource'; the ability to pass a Proc " \
      'will be removed in a future version of Sinja.' if konst.instance_of?(Proc)

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
        define_method(:sanity_check!) do |*args|
          super(resource_name, *args)
        end
      end

      before %r{/(?<id>[^/]+)(?:/.+)?} do |id|
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

  alias resources resource

  def sinja
    if block_given?
      yield _sinja
    else
      _sinja
    end
  end

  alias configure_jsonapi sinja
  def freeze_jsonapi
    _sinja.freeze
  end

  def self.extended(base)
    def base.route(*, **opts)
      opts[:qparams] ||= []

      super
    end
  end
end
