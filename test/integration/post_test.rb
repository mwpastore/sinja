# frozen_string_literal: true
require_relative 'test_helper'
require_relative '../../demo-app/app'

class PostTest < SequelTest
  include MyAppTest
  include Rack::Test::Methods

  def app
    Sinatra::Application.new
  end

  def test_missing_client_id
    login 'all@yourbase.com'
    post '/posts', JSON.generate(:data=>{
      :type=>'posts',
      :attributes=>{
        :title=>'This is a post',
        :body=>'This is a post body'
      }
    })
    assert_error 403, /not provided/
  end

  def test_validation_exception
    login 'all@yourbase.com'
    post '/posts', JSON.generate(:data=>{
      :type=>'posts',
      :id=>'foo-bar',
      :attributes=>{
        :title=>'This is a post',
        :body=>'This is a post body'
      }
    })
    assert_error 422
    assert_equal '/data/attributes/author', json[:errors].first[:source][:pointer]
    assert_empty DB[:posts].all
  end

  def test_sideload_on_create
    author_id = DB[:authors].insert :email=>'foo@example.com'
    login 'foo@example.com'

    DB[:tags].multi_insert [{ :name=>'teapots' }, { :name=>'sassafrass' }]
    tag_ids = DB[:tags].select_order_map(:id)

    slug = 'foo-bar'

    post '/posts', JSON.generate(:data=>{
      :type=>'posts',
      :id=>slug,
      :attributes=>{
        :title=>'This is a post',
        :body=>'This is a post body'
      },
      :relationships=>{
        :author=>{
          :data=>{
            :type=>'authors',
            :id=>author_id
          }
        },
        :tags=>{
          :data=>tag_ids.map { |id| { :type=>'tags', :id=>id }}
        }
      }
    })
    assert_ok

    assert_equal author_id, DB[:posts].first(:slug=>slug)[:author_id]
    assert_equal tag_ids, DB[:posts_tags].where(:post_slug=>slug).select_order_map(:tag_id)
  end

  def test_sideload_on_update
    author_id = DB[:authors].insert :email=>'foo@example.com'
    DB[:tags].multi_insert [{ :name=>'teapots' }, { :name=>'sassafrass' }]
    tag_ids = DB[:tags].select_order_map(:id)
    slug = 'foo-bar'
    DB[:posts].insert :slug=>slug, :title=>'This is a post', :body=>'This is a post body', :author_id=>author_id
    DB[:posts_tags].insert :post_slug=>slug, :tag_id=>tag_ids.first

    login 'foo@example.com'

    patch "/posts/#{slug}", JSON.generate(:data=>{
      :type=>'posts',
      :id=>slug,
      :attributes=>{
        :body=>'This is a different post body'
      },
      :relationships=>{
        :tags=>{
          :data=>[{ :type=>'tags', :id=>tag_ids.last }]
        }
      }
    })

    assert_ok
    assert_equal [tag_ids.last], DB[:posts_tags].where(:post_slug=>slug).select_order_map(:tag_id)
    assert_match %r{different}, DB[:posts].first(:slug=>slug)[:body]
  end

  def test_slug_update
    # https://github.com/jeremyevans/sequel/issues/1275
    skip if defined?(JRUBY_VERSION)

    author_id = DB[:authors].insert :email=>'foo@example.com'
    DB[:tags].multi_insert [{ :name=>'teapots' }, { :name=>'sassafrass' }]
    tag_ids = DB[:tags].select_order_map(:id)
    slug = 'foo-bar'
    DB[:posts].insert :slug=>slug, :title=>'This is a post', :body=>'This is a post body', :author_id=>author_id
    DB[:posts_tags].multi_insert [
      { :post_slug=>slug, :tag_id=>tag_ids.first },
      { :post_slug=>slug, :tag_id=>tag_ids.last }
    ]

    login 'foo@example.com'

    new_slug = 'bar-qux'
    patch "/posts/#{slug}", JSON.generate(:data=>{
      :type=>'posts',
      :id=>slug,
      :attributes=>{ :slug=>new_slug }
    })

    assert_ok
    assert_equal tag_ids, DB[:posts_tags].where(:post_slug=>new_slug).select_order_map(:tag_id)
    assert_match %r{a post body}, DB[:posts].first(:slug=>new_slug)[:body]
  end

  def test_owner_cant_change_author
    author_id = DB[:authors].insert :email=>'foo@example.com'
    slug = 'foo-bar'
    DB[:posts].insert :slug=>slug, :title=>'This is a post', :body=>'This is a post body', :author_id=>author_id

    login 'foo@example.com'

    patch "/posts/#{slug}/relationships/author", JSON.generate(:data=>{
      :type=>'authors',
      :id=>1
    })

    assert_error 403
    assert_equal author_id, DB[:posts].first(:slug=>slug)[:author_id]
  end

  def test_superuser_can_change_author
    author_id = DB[:authors].insert :email=>'foo@example.com'
    slug = 'foo-bar'
    DB[:posts].insert :slug=>slug, :title=>'This is a post', :body=>'This is a post body', :author_id=>author_id

    login 'all@yourbase.com'

    patch "/posts/#{slug}/relationships/author", JSON.generate(:data=>{
      :type=>'authors',
      :id=>1
    })

    assert_ok
    assert_equal 1, DB[:posts].first(:slug=>slug)[:author_id]
  end

  def test_related_resource_not_found
    author_id = DB[:authors].insert :email=>'foo@example.com'
    slug = 'foo-bar'
    DB[:posts].insert :slug=>slug, :title=>'This is a post', :body=>'This is a post body', :author_id=>author_id
    login 'foo@example.com'
    post "/posts/#{slug}/relationships/tags", JSON.generate(:data=>[{ :type=>'tags', :id=>99999 }])
    assert_error 404
  end

  def test_owner_can_add_missing_tags
    author_id = DB[:authors].insert :email=>'foo@example.com'
    DB[:tags].multi_insert [{ :name=>'teapots' }, { :name=>'sassafrass' }]
    tag_ids = DB[:tags].select_order_map(:id)
    slug = 'foo-bar'
    DB[:posts].insert :slug=>slug, :title=>'This is a post', :body=>'This is a post body', :author_id=>author_id
    DB[:posts_tags].insert :post_slug=>slug, :tag_id=>tag_ids.first

    login 'foo@example.com'

    post "/posts/#{slug}/relationships/tags", JSON.generate(:data=>[
      { :type=>'tags', :id=>tag_ids.first },
      { :type=>'tags', :id=>tag_ids.last }
    ])

    assert_ok
    assert_equal tag_ids, DB[:posts_tags].where(:post_slug=>slug).select_order_map(:tag_id)
  end

  def test_owner_can_remove_present_tags
    author_id = DB[:authors].insert :email=>'foo@example.com'
    DB[:tags].multi_insert [{ :name=>'teapots' }, { :name=>'sassafrass' }]
    tag_ids = DB[:tags].select_order_map(:id)
    slug = 'foo-bar'
    DB[:posts].insert :slug=>slug, :title=>'This is a post', :body=>'This is a post body', :author_id=>author_id
    DB[:posts_tags].multi_insert [
      { :post_slug=>slug, :tag_id=>tag_ids.first },
      { :post_slug=>slug, :tag_id=>tag_ids.last }
    ]

    login 'foo@example.com'

    delete "/posts/#{slug}/relationships/tags", JSON.generate(:data=>[
      { :type=>'tags', :id=>tag_ids.first },
      { :type=>'tags', :id=>999999 }
    ])

    assert_ok
    assert_equal [tag_ids.last], DB[:posts_tags].where(:post_slug=>slug).select_order_map(:tag_id)
  end

  def test_owner_can_clear_tags
    author_id = DB[:authors].insert :email=>'foo@example.com'
    DB[:tags].multi_insert [{ :name=>'teapots' }, { :name=>'sassafrass' }]
    tag_ids = DB[:tags].select_order_map(:id)
    slug = 'foo-bar'
    DB[:posts].insert :slug=>slug, :title=>'This is a post', :body=>'This is a post body', :author_id=>author_id
    DB[:posts_tags].multi_insert [
      { :post_slug=>slug, :tag_id=>tag_ids.first },
      { :post_slug=>slug, :tag_id=>tag_ids.last }
    ]

    login 'foo@example.com'

    patch "/posts/#{slug}/relationships/tags", JSON.generate(:data=>[])

    assert_equal 204, last_response.status
    assert_empty last_response.body
    assert_empty DB[:posts_tags].where(:post_slug=>slug).select_order_map(:tag_id)
  end

  def test_anyone_can_pluck_author
    author_id = DB[:authors].insert :email=>'foo@example.com'
    slug = 'foo-bar'
    DB[:posts].insert :slug=>slug, :title=>'This is a post', :body=>'This is a post body', :author_id=>author_id
    get "/posts/#{slug}/relationships/author"
    assert_ok
    assert_equal 'authors', json[:data][:type]
    assert_equal author_id, json[:data][:id].to_i
  end
end
