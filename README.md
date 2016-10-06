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
    Post[id]
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
