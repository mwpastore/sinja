# Sinatra::JSONAPI::Resource

A [Sinatra][1] extension for quickly building RESTful, [JSON:API][2]-compliant
resource controllers, leveraging the excellent [JSONAPI::Serializers][3] gem.

**CAVEAT EMPTOR: This gem is under active development. Expect many breaking
changes!**

```ruby
class PostController < Sinatra::Base
  register Sinatra::JSONAPI::Resource

  list do
    Post.all
  end

  find do |id|
    Post[id.to_i]
  end

  create do |data|
    Post.create(data)
  end
end
```

Racking up the above at `/posts` would enable the following endpoints (with all
other JSON:API endpoints returning 405):

* `GET /posts`
* `GET /posts/<id>`
* `POST /posts`

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sinatra-jsonapi-resource'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sinatra-jsonapi-resource

## Goals &amp; Assumptions

* Conform to the JSON:API spec
* Expose flexibility where the JSON:API spec is loose
* Controllers should be primarily composed of business logic
* Controllers sit in a middleware stack with authentication (e.g.
  [Rodauth][5]), attack protection (e.g. [Rack::Protection][6]), etc. above
  them
* Controllers sit beneath a router (e.g. [Rack::URLMap][4])
* Be ORM-agnostic (bring your own models)
* Play nice with Sinatra and JSONAPI::Serializers, allowing application
  developers to use those libraries as intended without jumping through hoops

## Design

We want to provide some collection of Sinatra extensions that add helpers,
conditions, filters, routes, and more. We'll use Sinatra's extension API
internally to compose functionality, and make two main entry points
(Sinatra::JSONAPI and Sinatra::JSONAPI::Resource) public. We can extend
Sinatra's DSL to allow application developers to register helpers with
predetermined names ("actions") and functionality, and dynamically create
nested routes and helpers for relationships.

### Wishlist

* Tighter integration with JSONAPI::Serializers (JAS); specifically, using
  links metadata to draw routes (may require improvements to JAS to allow moar
  introspection)
* Collect registered controllers and present a route map (this will likely need
  to be a separate gem&mdash;more like a framework&mdash;that wraps this one)
* Slightly related, can we provide some JWT middleware/boilerplate?
* We are bypassing so much of Sinatra, can we lift this code and maybe part of
  Sinatra into something more bare-metal?

## Usage

### Configuration

### Inheritance

### Models

### Serializers

### Query Parameters

### Authentication

### Authorization

### Conflicts

### Relationships

### Sinatra::JSONAPI

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/mwpastore/sinatra-jsonapi-resource.

## License

The gem is available as open source under the terms of the [MIT
License](http://opensource.org/licenses/MIT).

[1]: http://www.sinatrarb.com
[2]: http://jsonapi.org
[3]: https://github.com/fotinakis/jsonapi-serializers
[4]: http://www.rubydoc.info/github/rack/rack/master/Rack/URLMap
[5]: http://rodauth.jeremyevans.net
[6]: https://github.com/sinatra/sinatra/tree/master/rack-protection
