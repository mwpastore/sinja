# frozen_string_literal: true
require_relative '../base'
require_relative '../database'

DB.create_table?(:comments) do
  primary_key :id
  foreign_key :author_id, :authors, :on_delete=>:cascade
  foreign_key :post_slug, :posts, :on_delete=>:cascade
  String :body, :text=>true, :null=>false
  DateTime :created_at
  DateTime :updated_at
end

class Comment < Sequel::Model
  plugin :timestamps

  many_to_one :author
  many_to_one :post

  def validate
    super
    validates_not_null [:author, :post]
  end
end

class CommentSerializer < BaseSerializer
  attribute :body

  has_one :author
  has_one :post
end

CommentController = proc do
  helpers do
    def find(id)
      Comment[id.to_i]
    end

    def role
      if resource&.author == current_user
        super.push(:owner)
      else
        super
      end
    end
  end

  show do |id|
    next find(id), include: 'author'
  end

  create(roles: :logged_in) do |attr|
    comment = Comment.new
    comment.set_fields(attr, %i[body])
    comment.save(validate: false)
    next_pk comment
  end

  update(roles: %i[owner superuser]) do |attr|
    resource.update_fields(attr, %i[body], validate: false, missing: :skip)
  end

  destroy(roles: %i[owner superuser]) do
    resource.destroy
  end

  has_one :post do
    pluck do
      resource.post
    end

    graft(roles: :superuser, sideload_on: :create) do |rio|
      resource.post = Post.with_pk!(rio[:id].to_i)
      resource.save_changes(validate: !sideloaded?)
    end
  end

  has_one :author do
    pluck do
      resource.author
    end

    graft(roles: :superuser, sideload_on: :create) do |rio|
      resource.author = Author.with_pk!(rio[:id].to_i)
      resource.save_changes(validate: !sideloaded?)
    end
  end
end
