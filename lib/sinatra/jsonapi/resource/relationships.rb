# frozen_string_literal: true
module Sinatra::JSONAPI::Resource::Relationships
  REL_ACTIONS = %i[
    pluck
    graft
    prune
  ]

  REL_ACTIONS.each do |rel_action|
    define_method(rel_action) do |**opts, &block|
      if opts.key?(:roles)
        fail "Roles not enforced for `#{rel_action}'" unless rel_action_roles.key?(rel_action)
        unless @rel or block
          rel_action_roles[rel_action][:__default] = Set[*opts[:roles]]
          return
        end
      end

      fail unless @rel # TODO: sneaky, do we need a real DSL here?
      rel_action_roles[rel_action][@rel] = Set[*opts[:roles]] if opts.key?(:roles)
      helpers { define_method("#{rel_action}_#{@rel}", &block) } if block
    end
  end

  def def_rel_get(rel, &block)
    rel_path = rel.to_s.tr('_', '-')
    ["/:id/relationships/#{rel_path}", "/:id/#{rel_path}"].each do |path|
      pluck = "pluck_#{rel}".to_sym
      send :get, path, :actions=>:find, :rel_actions=>pluck do |id|
        item = find(id)
        not_found unless item
        instance_exec send(pluck, item), &block
      end
    end
  end

  def def_rel_patch(rel, nullish)
    rel_path = rel.to_s.tr('_', '-')
    graft = "graft_#{rel}".to_sym
    prune = "prune_#{rel}".to_sym
    patch "/:id/relationships/#{rel_path}", :actions=>:find, :rel_actions=>[graft, prune] do |id|
      item = find(id)
      not_found unless item
      meth, *args = nullish.(data) ? [prune] : [graft, data]
      send(meth, item, *args)
      status 204
    end
  end

  def def_rel_post(rel)
    rel_path = rel.to_s.tr('_', '-')
    post "/:id/relationships/#{rel_path}", :actions=>:find do |id|
      item = find(id)
      not_found unless item

      # add member(s) to to-many relationship
    end
  end

  def def_rel_delete(rel)
    rel_path = rel.to_s.tr('_', '-')
    delete "/:id/relationships/#{rel_path}", :actions=>:find do |id|
      item = find(id)
      not_found unless item

      # remove member(s) from to-many relationship
    end
  end

  def has_one(rel)
    @rel = rel
    yield
    @rel = nil

    def_rel_get(rel) { |item| serialize_model(item) }
    def_rel_patch(rel, proc(&:nil?))
  end

  def has_many(rel)
    @rel = rel
    yield
    @rel = nil

    def_rel_get(rel) { |items| serialize_models(items) }
    def_rel_patch(rel, proc(&:empty?))
    def_rel_post(rel)
    def_rel_delete(rel)
  end

  def self.registered(app)
    app.set :rel_action_roles,
      REL_ACTIONS.map { |rel_action| [rel_action, { :__default=>Set.new }] }.to_h.freeze

    app.set :rel_actions do |*rel_actions|
      condition do
        rel_actions.all? do |rel_action|
          action, rel = rel_action.to_s.split('_', 2).map(&:to_sym)
          rel_action_roles = settings.rel_action_roles[action]
          roles = rel_action_roles[rel_action_roles.key?(rel) ? rel : :__default]
          halt 403 unless roles.empty? || Set[*role].intersect?(roles)
          halt 405 unless respond_to?(rel_action)
          true
        end
      end
    end
  end

  def self.inherited(subclass)
    subclass.rel_action_roles =
      Marshal.load(Marshal.dump(subclass.rel_action_roles)).freeze
  end
end
