# frozen_string_literal: true
require_relative '../base'
require_relative '../database'

DB.create_table?(:authors) do
  primary_key :id
  String :email, :null=>false, :unique=>true
  String :real_name
  String :display_name
  TrueClass :admin, :default=>false
  DateTime :created_at
  DateTime :updated_at
end

class Author < Sequel::Model
  plugin :timestamps
  plugin :boolean_readers

  finder def self.by_email(arg)
    where(:email=>arg)
  end

  one_to_many :comments
  one_to_many :posts
end

Author.create(email: 'all@yourbase.com', admin: true)

class AuthorSerializer < BaseSerializer
  attribute(:display_name) { object.display_name || 'Anonymous Coward' }

  has_many :comments
  has_many :posts
end

AuthorController = proc do
  helpers do
    def find(id)
      Author[id.to_i]
    end

    def role
      if resource == current_user
        super.push(:self)
      else
        super
      end
    end

    def fields
      %i[email real_name display_name].tap do |a|
        a << :admin if RoleList[:superuser] === role
      end
    end
  end

  show do |id|
    find(id)
  end

  index do
    Author.all
  end

  create do |attr|
    author = Author.new
    author.set_fields(attr, fields)
    author.save(validate: false)
  end

  update(roles: %i[self superuser]) do |attr|
    resource.update_fields(attr, fields, validate: false)
  end

  destroy(roles: %i[self superuser]) do
    resource.destroy
  end

  has_many :comments do
    fetch(roles: :logged_in) do
      resource.comments
    end
  end

  has_many :posts do
    fetch do
      resource.posts
    end
  end
end
