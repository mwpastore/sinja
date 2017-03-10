# frozen_string_literal: true
require_relative 'base'
require_relative 'post' # make sure we create the posts table before the join table

DB.create_table?(:tags) do
  primary_key :id
  String :name, null: false, unique: true
end

DB.create_table?(:posts_tags) do
  foreign_key :post_slug, :posts, type: String, null: false, on_delete: :cascade, on_update: :cascade
  foreign_key :tag_id, :tags, null: false, on_delete: :cascade
  primary_key [:post_slug, :tag_id]
  index [:tag_id, :post_slug]
end

class Tag < Sequel::Model
  set_allowed_columns :name

  many_to_many :posts, right_key: :post_slug
end

class TagSerializer < BaseSerializer
  attribute :name

  has_many :posts
end

TagController = proc do
  helpers do
    def find(id)
      Tag.with_pk(id.to_i)
    end
  end

  show

  index(sort_by: :name, filter_by: :name) do
    Tag.dataset
  end

  create(roles: :logged_in) do |attr|
    tag = Tag.new(attr)
    tag.save(validate: false)
    next_pk tag
  end

  destroy(roles: :superuser) do
    resource.destroy
  end

  has_many :posts do
    fetch do
      resource.posts_dataset
    end

    replace(roles: :logged_in) do |rios|
      add_remove(:posts, rios, :to_s) do |post|
        role?(:superuser) || post.author == current_user
      end
    end

    merge(roles: :logged_in) do |rios|
      add_missing(:posts, rios, :to_s) do |post|
        role?(:superuser) || post.author == current_user
      end
    end

    subtract(roles: :logged_in) do |rios|
      remove_present(:posts, rios, :to_s) do |post|
        role?(:superuser) || post.author == current_user
      end
    end
  end
end
