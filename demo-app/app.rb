# frozen_string_literal: true
require 'sinatra'
require 'sinatra/jsonapi'

require_relative 'classes/author'
require_relative 'classes/comment'
require_relative 'classes/post'
require_relative 'classes/tag'

require 'sinja/helpers/sequel'

configure_jsonapi do |c|
  c.conflict_exceptions << Sequel::ConstraintViolation
end

helpers do
  def current_user
    # TESTING/DEMO PURPOSES ONLY -- DO NOT DO THIS IN PRODUCTION
    Author.first_by_email(env['HTTP_X_EMAIL'])
  end

  def role
    [].tap do |a|
      a << :logged_in if current_user
      a << :superuser if current_user&.admin?
    end
  end

  def transaction(&block)
    DB.transaction(&block)
  end
end

resource :authors, AuthorController
resource :comments, CommentController
resource :posts, PostController
resource :tags, TagController

freeze_jsonapi
