# frozen_string_literal: true
require_relative 'base'

DB.create_table?(:posts) do
  String :slug, primary_key: true
  foreign_key :author_id, :authors, index: true, on_delete: :cascade
  String :title, null: false
  String :body, text: true, null: false
  Float :created_at
  Float :updated_at
end

class Post < Sequel::Model
  plugin :auto_validations, not_null: :presence
  plugin :timestamps
  plugin :update_primary_key

  set_allowed_columns :slug, :title, :body

  unrestrict_primary_key # allow client-generated slugs

  # jdbc-sqlite3 reports unexpected record counts with cascading updates, which
  # breaks Sequel (https://github.com/jeremyevans/sequel/issues/1275)
  self.require_modification = !defined?(JRUBY_VERSION)

  many_to_one :author
  one_to_many :comments
  many_to_many :tags, left_key: :post_slug

  def validate
    super
    validates_not_null :author
  end
end

class PostSerializer < BaseSerializer
  def id
    object.slug
  end

  attributes :title, :body

  has_one :author
  has_many :comments
  has_many :tags
end

PostController = proc do
  helpers do
    def find(slug)
      Post.with_pk(slug.to_s)
    end

    def role
      Array(super).tap do |a|
        a << :owner if resource&.author == current_user
      end
    end
  end

  show do
    next resource, include: %w[author comments tags]
  end

  show_many do |slugs|
    next Post.where_all(slug: slugs.map!(&:to_s)), include: %i[author tags]
  end

  index do
    Post.dataset
  end

  create(roles: :logged_in) do |attr, slug|
    attr[:slug] = slug

    post = Post.new(attr)
    post.save(validate: false)
    next_pk post
  end

  update(roles: %i[owner superuser]) do |attr|
    resource.set(attr)
    resource.save_changes(validate: false)
  end

  destroy(roles: %i[owner superuser]) do
    resource.destroy
  end

  has_one :author do
    pluck do
      resource.author
    end

    graft(roles: :superuser, sideload_on: :create) do |rio|
      halt 403, 'You may only assign yourself as post author!' \
        unless role?(:superuser) || rio[:id].to_i == current_user.id

      resource.author = Author.with_pk!(rio[:id].to_i)
      resource.save_changes(validate: !sideloaded?)
    end
  end

  has_many :comments do
    fetch do
      next resource.comments_dataset, include: 'author'
    end
  end

  has_many :tags do
    fetch do
      resource.tags_dataset
    end

    clear(roles: %i[owner superuser], sideload_on: :update) do
      resource.remove_all_tags
    end

    replace(roles: %i[owner superuser], sideload_on: :update) do |rios|
      add_remove(:tags, rios)
    end

    merge(roles: %i[owner superuser], sideload_on: :create) do |rios|
      add_missing(:tags, rios)
    end

    subtract(roles: %i[owner superuser]) do |rios|
      remove_present(:tags, rios)
    end
  end
end
