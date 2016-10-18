# Sinja (Sinatra::JSONAPI)

A [Sinatra][1] [extension][10] for quickly building RESTful,
[JSON:API][2]-compliant applications, leveraging the excellent
[JSONAPI::Serializers][3] gem.

**CAVEAT EMPTOR: This gem is under active development. Expect many breaking
changes!**

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

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sinja'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sinja

## Goals &amp; Assumptions

* Conform to the JSON:API spec
* Expose flexibility where the JSON:API spec is loose
* Controllers should be primarily composed of business logic
* Controllers sit at the "bottom" of a middleware stack, beneath a router (e.g.
  [Rack::URLMap][4]) and critical components such as authentication (e.g.
  [Rodauth][5]), attack protection (e.g. [Rack::Protection][6]), etc.
* Be ORM-agnostic (bring your own models)
* Play nice with Sinatra and JSONAPI::Serializers, allowing application
  developers to use those libraries as intended without jumping through hoops

## Design

This is an abstraction (and enhancement) of a collection of design patterns
I've used in the past to implement JSON:API-conforming web services in
Sinatra. It takes a surprising amount of boilerplate, but the [spec][7] is
clear enough that a good abstraction could allow developers to focus on the
business logic of their controllers, rather than e.g. parsing JSON and sending
the correct HTTP status codes.

This library lightly extends Sinatra's DSL and automates (so to speak; it's
more like a blueprint) the drawing of routes and request and response handling.
The workhorses are "action helpers": user-defined helper methods that are
called from the standard JSON:API routes as necessary. For example, the
following statements define an action helper named `create`&mdash;with access
restricted to the `:admin` role&mdash;that takes `data.attributes` and an
optional client-generated ID from the JSON:API request payload, and returns the
created model.

```ruby
create(:roles=>:admin) do |attr, id=nil|
  foo = Foo.new(attr)
  foo.pk = id if id
  foo.save!
  next foo, foo.pk
end
```

HTTP POST requests to the top-level route of this controller (i.e. `POST
/foos`) will fire this action helper, assuming the currently logged-in user has
the `:admin` role. It will halt with HTTP status code 409 if there's a
constraint violation. Note that you are responsible for defining `Foo` (the
model) using your preferred ORM as well as a [JSONAPI::Serializer][3]-based
`FooSerializer`.

## Features

* ORM-agnostic
* Role-based authorization
* To-one and to-many relationships
* Conflict (constraint violation) handling
* Side-loaded relationships (on resource creation)

## Feature Comparisons

| Feature         | [JSONAPI::Resources][8]      | Sinja                                            |
| :-------------- | :--------------------------- | :----------------------------------------------- |
| Resource        | Works with a Controller      | Extends a Controller                             |
| Serializer      | Built-in                     | [JSONAPI::Serializers][3]                        |
| Framework       | Rails                        | Sinatra, but easy to mount within others         |
| ORM             | ActiveRecord                 | BYO                                              |
| Routing         | ActionDispatch::Routing      | BYO                                              |
| Caching         | ActiveSupport::Cache         | BYO                                              |
| Authorization   | [Pundit][9]                  | Role-based (`roles` keyword and `role` helper)   |
| Immutability    | `immutable` method           | Omit mutator action helpers in Controller        |
| Fetchability    | `fetchable_fields` method    | Omit attributes in Serializer                    |
| Creatability    | `creatable_fields` method    | Handle in `create` action helper                 |
| Updatability    | `updatable_fields` method    | Handle in `update` action helper                 |
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

### Wishlist

* Tighter integration with JSONAPI::Serializers (JAS); specifically, using
  links metadata to draw routes (may require improvements to JAS to allow moar
  introspection)
* Collect registered controllers and present a route map (this will likely need
  to be a separate gem&mdash;more like a framework&mdash;that wraps this one)
* Slightly related, can we provide some JWT middleware/boilerplate?
* We are bypassing so much of Sinatra, can we lift this code and maybe part of
  Sinatra into something more bare-metal?
* Relationship discovery
* Don't draw routes if action helpers aren't defined

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
