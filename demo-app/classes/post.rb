# frozen_string_literal: true
require_relative '../base'
require_relative '../database'

DB.create_table?(:posts) do
  String :slug, :primary_key=>true
  foreign_key :author_id, :authors, :on_delete=>:cascade
  String :title, :null=>false
  String :body, :text=>true, :null=>false
  DateTime :created_at
  DateTime :updated_at
end

class Post < Sequel::Model
  plugin :timestamps

  unrestrict_primary_key

  many_to_one :author
  one_to_many :comments
  many_to_many :tags, :left_key=>:post_slug

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
      Post[slug.to_s]
    end

    def role
      if resource&.author == current_user
        super.push(:owner)
      else
        super
      end
    end
  end

  show do |slug|
    next find(slug), include: %w[author comments tags]
  end

  index do
    # TODO: Filter/sort by created_at and/or updated_at?
    Post.all
  end

  create(roles: :logged_in) do |attr, slug|
    post = Post.new
    post.set_fields(attr, %i[title body])
    post.slug = slug.to_s # set primary key
    post.save(validate: false)
    next_pk post
  end

  update(roles: %i[owner superuser]) do |attr|
    resource.update_fields(attr, %i[title body], validate: false, missing: :skip)
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
      next resource.comments, include: 'author'
    end
  end

  has_many :tags do
    fetch do
      resource.tags
    end

    merge(roles: %i[owner superuser], sideload_on: %i[create update]) do |rios|
      add_missing(:tags, rios)
    end

    subtract(roles: %i[owner superuser]) do |rios|
      remove_present(:tags, rios)
    end

    clear(roles: %i[owner superuser], sideload_on: :update) do
      resource.remove_all_tags
    end
  end
end
