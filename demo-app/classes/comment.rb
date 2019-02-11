# frozen_string_literal: true
require_relative 'base'

DB.create_table?(:comments) do
  primary_key :id
  foreign_key :author_id, :authors, null: false, index: true, on_delete: :cascade
  foreign_key :post_slug, :posts, type: String, null: false, index: true, on_delete: :cascade, on_update: :cascade
  String :body, text: true, null: false
  Float :created_at
  Float :updated_at
end

class Comment < Sequel::Model
  plugin :auto_validations, not_null: :presence
  plugin :timestamps

  set_allowed_columns :body

  many_to_one :author
  many_to_one :post
end

class CommentSerializer < BaseSerializer
  attribute :body

  has_one :author
  has_one :post
end

CommentController = proc do
  helpers do
    def find(id)
      Comment.with_pk(id.to_i)
    end

    def role
      Array(super).tap do |a|
        a << :owner if resource&.author == current_user
      end
    end
  end

  show do
    next resource, include: 'author'
  end

  create(roles: :logged_in) do |attr|
    next_pk Comment.new(attr)
  end

  update(roles: %i[owner superuser]) do |attr|
    resource.set(attr)
    resource.save_changes(validate: false)
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
      resource.save_changes unless sideloaded?
    end
  end

  has_one :author do
    pluck do
      resource.author
    end

    graft(roles: :superuser, sideload_on: :create) do |rio|
      halt 403, 'You may only assign yourself as comment author!' \
        unless role?(:superuser) || rio[:id].to_i == current_user.id

      resource.author = Author.with_pk!(rio[:id].to_i)
      resource.save_changes unless sideloaded?
    end
  end
end
