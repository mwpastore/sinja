# frozen_string_literal: true
require_relative '../base'
require_relative '../database'

require_relative 'post' # make sure we create the posts table before the join table

DB.create_table?(:tags) do
  primary_key :id
  String :name, :null=>false, :unique=>true
end

DB.create_table?(:posts_tags) do
  foreign_key :post_id, :posts, :null=>false, :on_delete=>:cascade
  foreign_key :tag_id, :tags, :null=>false, :on_delete=>:cascade
  primary_key [:post_id, :tag_id]
  index [:tag_id, :post_id]
end

class Tag < Sequel::Model
  many_to_many :posts
end

class TagSerializer < BaseSerializer
  attribute :name

  has_many :posts
end

TagController = proc do
  helpers do
    def find(id)
      Tag[id.to_i]
    end
  end

  show

  index do
    Tag.all
  end

  create(roles: :logged_in) do |attr|
    tag = Tag.new
    tag.set_fields(attr, %i[name])
    tag.save(validate: false)
  end

  destroy(roles: :superuser) do
    resource.destroy
  end

  has_many :posts do
    fetch do
      resource.posts
    end

    merge(roles: :logged_in) do |rios|
      add_missing(:posts, rios) do |post|
        Sinja::Roles[:superuser] === role || post.author == current_user
      end
    end

    subtract(roles: :logged_in) do |rios|
      remove_present(:posts, rios) do |post|
        Sinja::Roles[:superuser] === role || post.author == current_user
      end
    end
  end
end
