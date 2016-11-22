# frozen_string_literal: true
require_relative '../base'
require_relative '../database'

DB.create_table?(:posts) do
  String :slug, :primary_key=>true
  foreign_key :author_id, :authors, :null=>false, :deferrable=>true, :on_delete=>:cascade
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
  many_to_many :tags
end

class PostSerializer < BaseSerializer
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
    dataset =
      if author_id = params[:filter][:author]
        Post.where(author: Author.with_pk!(author_id.to_i))
      elsif tag_id = params[:filter][:tag]
        Post.where(tag: Tag.with_pk!(tag_id.to_i))
      else
        Post
      end

    dataset.all
  end

  create(roles: :logged_in) do |attr, slug|
    post = Post.new
    post.set_fields(attr, %i[title body])
    post.slug = slug.to_s # set primary key
    post.save

    next slug, post
  end

  update(roles: %i[owner superuser]) do |attr|
    resource.update_fields(attr, %i[title body])
  end

  destroy(roles: %i[owner superuser]) do
    resource.destroy
  end

  has_one :author do
    pluck do
      resource.author
    end

    graft do |rio|
      halt 403 unless RoleList[:superuser] === role || resource.author.nil?
      resource.author = Author.with_pk!(rio[:id].to_i)
      resource.save_changes
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

    clear(roles: %i[owner superuser]) do
      resource.remove_all_tags
    end

    merge(roles: %i[owner superuser]) do |rios|
      add_missing(:tags, rios)
    end

    subtract(roles: %i[owner superuser]) do |rios|
      remove_present(:tags, rios)
    end
  end
end
