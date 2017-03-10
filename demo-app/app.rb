# frozen_string_literal: true
require 'sinatra'
require 'sinatra/jsonapi'

# Load the Sequel helpers without registering the extension.
require 'sinja/sequel/helpers'

require_relative 'classes/author'
require_relative 'classes/comment'
require_relative 'classes/post'
require_relative 'classes/tag'

Sequel::Model.finalize_associations
Sequel::Model.freeze

DB.freeze

configure :development do
  set :server_settings, AccessLog: [] # avoid WEBrick double-logging issue
end

helpers Sinja::Sequel::Helpers do
  def current_user
    # TESTING/DEMO PURPOSES ONLY -- DO NOT DO THIS IN PRODUCTION
    @current_user ||= Author.first_by_email(env['HTTP_X_EMAIL']) if env.key?('HTTP_X_EMAIL')
  end

  def role
    return unless current_user

    [:logged_in].tap do |a|
      a << :superuser if current_user.admin?
    end
  end
end

resource :authors, &AuthorController
resource :comments, &CommentController
resource :posts, pkre: /[\w-]+/, &PostController
resource :tags, &TagController

freeze_jsonapi
