# Sinja (Sinatra::JSONAPI)

Sinja is a [Sinatra 2.0][1] [extension][10] for quickly building [RESTful][11],
[JSON:API][2]-[compliant][7] web services, leveraging the excellent
[JSONAPI::Serializers][3] gem. It enhances Sinatra's DSL to enable resource-,
relationship-, and role-centric definition of routes and helpers, and it
configures Sinatra with the proper settings, MIME-types, filters, conditions,
and error-handling to implement JSON:API. Sinja aims to be lightweight
(low-overhead), ORM-agnostic (to the extent that JSONAPI::Serializers is), and
opinionated (to the extent that the specification is).

```ruby
require 'sinatra'
require 'sinatra/jsonapi'

resource :posts do
  list do
    Post.all
  end

  find do |id|
    Post[id.to_i]
  end

  create do |attr|
    Post.create(attr)
  end
end
```

Assuming the presence of a `Post` model and serializer, running the above
"classic"-style Sinatra application would enable the following endpoints (with
all other JSON:API endpoints returning 404 or 405):

* `GET /posts`
* `GET /posts/<id>`
* `POST /posts`

**CAVEAT EMPTOR: This gem is still very new and under active development. The
API is mostly stable, but there still may be significant breaking changes. It
has not yet been thoroughly tested or vetted in a production environment.**

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sinja'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sinja

## Design

action helpers

## Features

* ORM-agnostic
* Role-based authorization
* To-one and to-many relationships
* Conflict (constraint violation) handling
* Side-loading on resource creation

Its main competitors in the Ruby space are [ActiveModelSerializers][12]
(AMS) with the JsonApi adapter and [JSONAPI::Resources][8] (JR), both of which
are designed to work with [Rails][16] and [ActiveRecord][17]/[ActiveModel][18]
(although they may work with [Sequel][13] via [sequel-rails][14] and Sequel's
[`:active_model` plugin][15]). Otherwise, you might use something like Sinatra,
[Roda][20], or [Grape][19] with JSONAPI::Serializers, your own routes, and a
ton of boilerplate.

### Comparison with JSONAPI::Resources (JR)

| Feature         | JR                           | Sinja                                            |
| :-------------- | :--------------------------- | :----------------------------------------------- |
| Serializer      | Built-in                     | [JSONAPI::Serializers][3]                        |
| Framework       | Rails                        | Sinatra, but easy to mount within others         |
| Routing         | ActionDispatch::Routing      | Mustermann                                       |
| Caching         | ActiveSupport::Cache         | BYO                                              |
| ORM             | ActiveRecord/ActiveModel     | BYO                                              |
| Authorization   | [Pundit][9]                  | Role-based (`roles` keyword and `role` helper)   |
| Immutability    | `immutable` method           | Omit mutator action helpers                      |
| Fetchability    | `fetchable_fields` method    | Omit attributes in Serializer                    |
| Creatability    | `creatable_fields` method    | Handle in `create` action helper or Model\*      |
| Updatability    | `updatable_fields` method    | Handle in `update` action helper or Model\*      |
| Sortability     | `sortable_fields` method     | Handle `params[:sort]` in `list` action helper   |
| Default sorting | `default_sort` method        | Set default for `params[:sort]`                  |
| Context         | `context` method             | Rack middleware (e.g. `env['context']`)          |
| Attributes      | Define in Model and Resource | Define in Model\* and Serializer                 |
| Formatting      | `format` attribute keyword   | Define attribute as a method in Serialier        |
| Relationships   | Define in Model and Resource | Define in Model, Controller, and Serializer      |
| Filters         | `filter(s)` keywords         | Handle `params[:filter]` in `list` action helper |
| Default filters | `default` filter keyword     | Set default for `params[:filter]`                |

\* - Depending on your ORM.

This list is incomplete.

* Primary keys
* Pagination
* Custom links
* Meta
* Side-loading (on request and response)
* Namespaces
* Configuration

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
https://github.com/mwpastore/sinja.

## License

The gem is available as open source under the terms of the [MIT
License](http://opensource.org/licenses/MIT).

[1]: http://www.sinatrarb.com
[2]: http://jsonapi.org
[3]: https://github.com/fotinakis/jsonapi-serializers
[4]: http://www.rubydoc.info/github/rack/rack/master/Rack/URLMap
[5]: http://rodauth.jeremyevans.net
[6]: https://github.com/sinatra/sinatra/tree/master/rack-protection
[7]: http://jsonapi.org/format/
[8]: https://github.com/cerebris/jsonapi-resources
[9]: https://github.com/cerebris/jsonapi-resources#authorization
[10]: http://www.sinatrarb.com/extensions-wild.html
[11]: https://en.wikipedia.org/wiki/Representational_state_transfer
[12]: https://github.com/rails-api/active_model_serializers
[13]: http://sequel.jeremyevans.net
[14]: http://talentbox.github.io/sequel-rails/
[15]: http://sequel.jeremyevans.net/rdoc-plugins/classes/Sequel/Plugins/ActiveModel.html
[16]: http://rubyonrails.org
[17]: https://github.com/rails/rails/tree/master/activerecord
[18]: https://github.com/rails/rails/tree/master/activemodel
[19]: http://www.ruby-grape.org
[20]: http://roda.jeremyevans.net
