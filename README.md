# Sinja (Sinatra::JSONAPI)

[![Build Status](https://travis-ci.org/mwpastore/sinja.svg?branch=master)](https://travis-ci.org/mwpastore/sinja)
[![Gem Version](https://badge.fury.io/rb/sinja.svg)](https://badge.fury.io/rb/sinja)

Sinja is a [Sinatra 2.0][1] [extension][10] for quickly building [RESTful][11],
[JSON:API][2]-[compliant][7] web services, leveraging the excellent
[JSONAPI::Serializers][3] gem. It enhances Sinatra's DSL to enable resource-,
relationship-, and role-centric definition of routes and helpers, and it
configures Sinatra with the proper settings, MIME-types, filters, conditions,
and error-handling to implement JSON:API. Sinja aims to be lightweight
(low-overhead), ORM-agnostic (to the extent that JSONAPI::Serializers is), and
opinionated (to the extent that the specification is).

**CAVEAT EMPTOR: This gem is still very new and under active development. The
API is mostly stable, but there still may be significant breaking changes. It
has not yet been thoroughly tested or vetted in a production environment.**

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Synopsis](#synopsis)
- [Installation](#installation)
- [Features](#features)
  - [Extensibility](#extensibility)
    - [Public APIs](#public-apis)
  - [Performance](#performance)
  - [Comparison with JSONAPI::Resources (JR)](#comparison-with-jsonapiresources-jr)
- [Usage](#usage)
  - [Configuration](#configuration)
    - [Sinatra](#sinatra)
    - [Sinja](#sinja)
  - [Action Helpers](#action-helpers)
    - [`resource`](#resource)
      - [`index {..}` => Array](#index---array)
      - [`show {|id| ..}` => Object](#show-id---object)
      - [`create {|attr, id| ..}` => id, Object?](#create-attr-id---id-object)
      - [`create {|attr| ..}` => id, Object](#create-attr---id-object)
      - [`update {|attr| ..}` => Object?](#update-attr---object)
      - [`destroy {..}`](#destroy-)
    - [`has_one`](#has_one)
      - [`pluck {..}` => Object](#pluck---object)
      - [`prune {..}` => TrueClass?](#prune---trueclass)
      - [`graft {|rio| ..}` => TrueClass?](#graft-rio---trueclass)
    - [`has_many`](#has_many)
      - [`fetch {..}` => Array](#fetch---array)
      - [`clear {..}` => TrueClass?](#clear---trueclass)
      - [`merge {|rios| ..}` => TrueClass?](#merge-rios---trueclass)
      - [`subtract {|rios| ..}` => TrueClass?](#subtract-rios---trueclass)
  - [Authorization](#authorization)
    - [`default_roles` configurable](#default_roles-configurable)
    - [`:roles` Action Helper option](#roles-action-helper-option)
    - [`role` helper](#role-helper)
  - [Conflicts](#conflicts)
  - [Transactions](#transactions)
  - [Module Namespaces](#module-namespaces)
  - [Code Organization](#code-organization)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Synopsis

```ruby
require 'sinatra'
require 'sinatra/jsonapi'

resource :posts do
  index do
    Post.all
  end

  show do |id|
    Post[id.to_i]
  end

  create do |attr|
    Post.create(attr)
  end
end

freeze_jsonapi
```

Assuming the presence of a `Post` model and serializer, running the above
"classic"-style Sinatra application would enable the following endpoints (with
all other JSON:API endpoints returning 404 or 405):

* `GET /posts`
* `GET /posts/<id>`
* `POST /posts`

Of course, "modular"-style Sinatra aplications require you to register the
extension:

```ruby
require 'sinatra/base'
require 'sinatra/jsonapi'

class App < Sinatra::Base
  register Sinatra::JSONAPI

  resource :posts do
    # ..
  end

  freeze_jsonapi
end
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sinja'
```

And then execute:

```sh
$ bundle
```

Or install it yourself as:

```sh
$ gem install sinja
```

## Features

* ORM-agnostic
* Role-based authorization
* To-one and to-many relationships
* Side-loaded relationships on resource creation
* Conflict (constraint violation) handling
* Plus all the features of JSONAPI::Serializers!

Its main competitors in the Ruby space are [ActiveModelSerializers][12] (AMS)
with the JsonApi adapter and [JSONAPI::Resources][8] (JR), both of which are
designed to work with [Rails][16] and [ActiveRecord][17]/[ActiveModel][18]
(although they may work with [Sequel][13] via [sequel-rails][14] and Sequel's
[`:active_model` plugin][15]). Otherwise, you might use something like Sinatra,
[Roda][20], or [Grape][19] with JSONAPI::Serializers, your own routes, and a
ton of boilerplate. The goal of this extension is to provide most or all of the
boilerplate for a Sintara application and automate the drawing of routes based
on the resource definitions.

### Extensibility

The "power" of implementing this functionality as a Sinatra extension is that
all of Sinatra's usual features are available within your resource definitions.
The action helpers blocks get compiled into Sinatra helpers, and the
`resource`, `has_one`, and `has_many` keywords simply build
[Sinatra::Namespace][21] blocks. You can manage caching directives, set
headers, and even `halt` (or `not_found`) out of action helpers as desired.

```ruby
class App < Sinatra::Base
  register Sinatra::JSONAPI

  # <- This is a Sinatra::Base class definition. (Duh.)

  resource :books do
    # <- This is a Sinatra::Namespace block.

    show do |id|
      # <- This is a Sinatra helper, scoped to the resource namespace.
    end

    has_one :author do
      # <- This is a Sinatra::Namespace block, nested under the resource namespace.

      pluck do
        # <- This is a Sinatra helper, scoped to the nested namespace.
      end
    end
  end

  freeze_jsonapi
end
```

This lets you easily pepper in all the syntactic sugar you might expect to see
in a typical Sinatra application:

```ruby
class App < Sinatra::Base
  register Sinatra::JSONAPI

  configure :development do
    enable :logging
  end

  helpers do
    def foo; true end
  end

  before do
    cache_control :public, :max_age=>3_600
  end

  # define a custom /status route
  get('/status', :provides=>:json) { 'OK' }

  resource :books do
    show do |id|
      book = Book[id.to_i]
      not_found "Book #{id} not found!" unless book
      headers 'X-ISBN'=>book.isbn
      last_modified book.updated_at
      next book, :include=>%w[author]
    end

    has_one :author do
      helpers do
        def bar; false end
      end

      before do
        cache_control :private
        halt 403 unless foo || bar
      end

      pluck do
        etag resource.author.hash, :weak
        resource.author
      end
    end

    # define a custom /books/top10 route
    get '/top10' do
      serialize_models Book.where{}.reverse_order(:recent_sales).limit(10).all
    end
  end

  freeze_jsonapi
end
```

#### Public APIs

**data**
: Returns the `data` key of the deserialized request payload (with symbolized
  names).

**serialize_model**
: Takes a model (and optional hash of JSONAPI::Serializers options) and returns
  a serialized model.

**serialize_model?**
: Takes a model (and optional hash of JSONAPI::Serializers options) and returns
  a serialized model if non-`nil`, or the root metadata if present, or a HTTP
  status 204.

**serialize_models**
: Takes an array of models (and optional hash of JSONAPI::Serializers options)
  and returns a serialized collection.

**serialize_models?**
: Takes an array of models (and optional hash of JSONAPI::Serializers options)
  and returns a serialized collection if non-empty, or the root metadata if
  present, or a HTTP status 204.

### Performance

Although there is some heavy metaprogramming happening at boot time, the end
result is simply a collection of Sinatra namespaces, routes, filters,
conditions, helpers, etc., and Sinja applications should perform as if you had
written them verbosely. The main caveat is that there are quite a few block
closures, which don't perform as well as normal methods in Ruby. Feedback
welcome.

### Comparison with JSONAPI::Resources (JR)

| Feature         | JR                           | Sinja                                             |
| :-------------- | :--------------------------- | :------------------------------------------------ |
| Serializer      | Built-in                     | [JSONAPI::Serializers][3]                         |
| Framework       | Rails                        | Sinatra, but easy to mount within others          |
| Routing         | ActionDispatch::Routing      | Mustermann                                        |
| Caching         | ActiveSupport::Cache         | BYO                                               |
| ORM             | ActiveRecord/ActiveModel     | BYO                                               |
| Authorization   | [Pundit][9]                  | Role-based (`roles` keyword and `role` helper)    |
| Immutability    | `immutable` method           | Omit mutator action helpers                       |
| Fetchability    | `fetchable_fields` method    | Omit attributes in Serializer                     |
| Creatability    | `creatable_fields` method    | Handle in `create` action helper or Model\*       |
| Updatability    | `updatable_fields` method    | Handle in `update` action helper or Model\*       |
| Sortability     | `sortable_fields` method     | Handle `params[:sort]` in `index` action helper   |
| Default sorting | `default_sort` method        | Set default for `params[:sort]`                   |
| Context         | `context` method             | Rack middleware (e.g. `env['context']`)           |
| Attributes      | Define in Model and Resource | Define in Model\* and Serializer                  |
| Formatting      | `format` attribute keyword   | Define attribute as a method in Serialier         |
| Relationships   | Define in Model and Resource | Define in Model, Resource, and Serializer         |
| Filters         | `filter(s)` keywords         | Handle `params[:filter]` in `index` action helper |
| Default filters | `default` filter keyword     | Set default for `params[:filter]`                 |

\* - Depending on your ORM.

This list is incomplete. TODO:

* Primary keys
* Pagination
* Custom links
* Meta
* Side-loading (on request and response)
* Namespaces
* Configuration
* Validation

## Usage

You'll need a database schema and models (using the engine and ORM of your
choice) and [serializers][3] to get started. Create a new Sinatra application
(classic or modular) to hold all your JSON:API endpoints and (if modular)
register this extension. Instead of defining routes with `get`, `post`, etc. as
you normally would, simply define `resource` blocks with action helpers and
`has_one` and `has_many` relationship blocks (with their own action helpers).
Sinja will draw and enable the appropriate routes based on the defined
resources, relationships, and action helpers. Other routes will return the
appropriate HTTP status codes: 403, 404, or 405.

### Configuration

#### Sinatra

Registering this extension has a number of application-wide implications,
detailed below. If you have any non-JSON:API routes, you may want to keep them
in a separate Sinatra application and incorporate them as middleware or mount
them elsewhere (e.g. with [Rack::URLMap][4]), or host them as a completely
separate web service. It may not be feasible to have custom routes that don't
conform to these settings.

* Registers [Sinatra::Namespace][21]
* Disables [Rack::Protection][6] (can be reenabled with `enable :protection` or
  by manually `use`-ing the Rack::Protection middleware)
* Disables static file routes (can be reenabled with `enable :static`)
* Sets `:show_exceptions` to `:after_handler`
* Adds an `:api_json` MIME-type (`Sinatra::JSONAPI::MIME_TYPE`)
* Enforces strict checking of the `Accept` and `Content-Type` request headers
* Sets the `Content-Type` response header to `:api_json` (can be overriden with
  the `content_type` helper)
* Formats all errors to the proper JSON:API structure
* Serializes all response bodies (including errors) to JSON

#### Sinja

Sinja provides its own configuration store that can be accessed through the
`configure_jsonapi` block. The following configurables are available (with
their defaults shown):

```ruby
configure_jsonapi do |c|
  #c.conflict_exceptions = [] # see "Conflicts" below

  #c.default_roles = {} # see "Authorization" below

  # Set the "progname" used by Sinja when accessing the logger
  #c.logger_progname = 'sinja'

  # A hash of options to pass to JSONAPI::Serializer.serialize
  #c.serializer_opts = {}

  # JSON methods to use when serializing response bodies and errors
  #c.json_generator = development? ? :pretty_generate : :generate
  #c.json_error_generator = development? ? :pretty_generate : :fast_generate
end
```

After Sinja is configured and all your resources are defined, you should call
`freeze_jsonapi` to freeze the configuration store.

### Action Helpers

Action helpers should be defined within the appropriate block contexts
(`resource`, `has_one`, or `has_many`) using the given keywords and arguments
below. Implicitly return the expected values as described below (as an array if
necessary) or use the `next` keyword (instead of `return` or `break`) to exit
the action helper. Return values marked with a question mark below may be
omitted entirely. Any helper may additionally return an options hash to pass
along to JSONAPI::Serializers.

The `:include` and `:fields` query parameters are automatically passed through
to JSONAPI::Serializers. To disable this behavior for any given query
parameter, force it to an (empty) array in the aforementioned options hash. You
may also use the special `:exclude` option to preserve the default pass-through
behavior while preventing specific relationships from being included in the
response. This accepts the same formats as JSONAPI::Serializers accepts for
`:include`. If you exclude a relationship, any sub-relationships will also be
excluded. The `:sort`, `:page`, and `:filter` query parameters must be handled
manually.

```ruby
resource :foos do
  index do
    next Foo.all, :exclude=>%w[bars] # disallow including bars and bars.quxes
  end

  has_many :bars
end

resource :bars do
  index do
    [Bar.all, :fields=>[]] # disallow sparse fieldsets
  end

  has_one :foo
  has_many :quxes
end
```

All arguments to action helpers are "tainted" and should be treated as
potentially dangerous: IDs, attribute hashes, and [resource identifier
objects][22].

Finally, some routes will automatically invoke the `show` action helper on your
behalf and make the selected resource available to other action helpers as
`resource`. You've already told Sinja how to find a resource by ID, so why
repeat yourself? For example, the `PATCH /<name>/:id` route looks up the
resource with that ID using the `show` action helper and makes it available to
the `update` action helper as `resource`. The same goes for the `DELETE
/<name>/:id` route and the `destroy` action helper, and all of the `has_one`
and `has_many` action helpers.

#### `resource`

##### `index {..}` => Array

Return an array of zero or more objects to serialize on the response.

##### `show {|id| ..}` => Object

Take an ID and return the corresponding object (or `nil` if not found) to
serialize on the response.

##### `create {|attr, id| ..}` => id, Object?

With client-generated IDs: Take a hash of attributes and a client-generated ID,
create a new resource, and return the ID and optionally the created resource.
(Note that only one or the other `create` action helpers is allowed in any
given resource block.)

##### `create {|attr| ..}` => id, Object

Without client-generated IDs: Take a hash of attributes, create a new resource,
and return the server-generated ID and the created resource. (Note that only
one or the other `create` action helpers is allowed in any given resource
block.)

##### `update {|attr| ..}` => Object?

Take a hash of attributes, update `resource`, and optionally return the updated
resource.

##### `destroy {..}`

Delete or destroy `resource`.

#### `has_one`

##### `pluck {..}` => Object

Return the related object vis-&agrave;-vis `resource` to serialize on the
response. Defined by default as `resource.send(<to-one>)`.

##### `prune {..}` => TrueClass?

Remove the relationship from `resource`. To serialize the updated linkage on
the response, refresh or reload `resource` (if necessary) and return a truthy
value.

For example, using Sequel:

```ruby
has_one :qux do
  prune do
    resource.qux = nil
    resource.save_changes # will return truthy if the relationship was present
  end
end
```

##### `graft {|rio| ..}` => TrueClass?

Take a [resource identifier object][22] and update the relationship on
`resource`. To serialize the updated linkage on the response, refresh or reload
`resource` (if necessary) and return a truthy value.

#### `has_many`

##### `fetch {..}` => Array

Return an array of related objects vis-&agrave;-vis `resource` to serialize on
the response. Defined by default as `resource.send(<to-many>)`.

##### `clear {..}` => TrueClass?

Remove all relationships from `resource`. To serialize the updated linkage on
the response, refresh or reload `resource` (if necessary) and return a truthy
value.

For example, using Sequel:

```ruby
has_many :bars do
  clear do
    resource.remove_all_bars # will return truthy if relationships were present
  end
end
```

##### `merge {|rios| ..}` => TrueClass?

Take an array of [resource identifier objects][22] and update (add unless
already present) the relationships on `resource`. To serialize the updated
linkage on the response, refresh or reload `resource` (if necessary) and return
a truthy value.

##### `subtract {|rios| ..}` => TrueClass?

Take an array of [resource identifier objects][22] and update (remove unless
already missing) the relationships on `resource`. To serialize the updated
linkage on the response, refresh or reload `resource` (if necessary) and return
a truthy value.

### Authorization

Sinja provides a simple role-based authorization scheme to restrict access to
routes based on the action helpers they invoke. For example, you might say all
logged-in users have access to `index`, `show`, `pluck`, and `fetch` (the
read-only action helpers), but only administrators have access to `create`,
`update`, etc. (the read-write action helpers). You can have as many roles as
you'd like, e.g. a super-administrator role to restrict access to `destroy`.
Users can be in one or more roles, and action helpers can be restricted to one
or more roles for maximum flexibility. There are three main components to the
scheme:

#### `default_roles` configurable

You set the default roles for the entire Sinja application in the top-level
configuration. Action helpers without any default roles are unrestricted by
default.

```ruby
configure_jsonapi do |c|
  c.default_roles = {
    # Resource roles
    :index=>:user,
    :show=>:user,
    :create=>:admin,
    :update=>:admin,
    :destroy=>:super,

    # To-one relationship roles
    :pluck=>:user,
    :prune=>:admin,
    :graft=>:admin,

    # To-many relationship roles
    :fetch=>:user,
    :clear=>:admin,
    :merge=>:admin,
    :subtract=>:admin
  }
end
```

#### `:roles` Action Helper option

To override the default roles for any given action helper, simply specify a
`:roles` option when defining it. To remove all restrictions from an action
helper, set `:roles` to an empty array. For example, to manage access to
`show` at different levels of granularity (with the above `default_roles`):

```ruby
resource :foos do
  show do
    # any logged-in user (with the :user role) can access /foos/:id
  end
end

resource :bars do
  show(:roles=>:admin) do
    # only logged-in users with the :admin role can access /bars/:id
  end
end

resource :quxes do
  show(:roles=>[]) do
    # anyone (bypassing the `role' helper) can access /quxes/:id
  end
end
```

#### `role` helper

Finally, define a `role` helper in your application that returns the user's
role(s) (if any). You can handle login failures in your middleware, elsewhere
in the application (i.e. a `before` filter), or within in the helper, simply
letting Sinja halt 403 on restricted action helpers when `role` returns `nil`
(the default behavior).

```ruby
helpers do
  def role
    env['my_auth_middleware'].login!
    session[:roles]
  rescue MyAuthenticationFailure=>e
    nil
  end
end
```

### Conflicts

If your database driver raises exceptions on constraint violations, you should
specify which exception class(es) should be handled and return HTTP status code
409.

For example, using Sequel:

```ruby
configure_jsonapi do |c|
  c.conflict_exceptions = [Sequel::ConstraintViolation]
end
```

### Transactions

If your database driver support transactions, you should define a yielding
`transaction` helper in your application for Sinja to use when working with
sideloaded data in the request. For example, if relationship data is provided
in the request payload when creating resources, Sinja will automatically farm
out to other routes to build those relationships after the resource is created.
If any step in that process fails, ideally the parent resource and any
relationships would be rolled back before returning an error message to the
requester.

For example, using Sequel with the database handle stored in the constant `DB`:

```ruby
helpers do
  def transaction
    DB.transaction { yield }
  end
end
```

### Module Namespaces

Everything is dual-namespaced under both Sinatra::JSONAPI and Sinja, and Sinja
requires Sinatra::Base, so this:

```ruby
require 'sinatra/jsonapi'

class App < Sinatra::Base
  register Sinatra::JSONAPI

  configure_jsonapi do |c|
    # ..
  end

  # ..

  freeze_jsonapi
end
```

Can also be written like this:

```ruby
require 'sinja'

class App < Sinatra::Base
  register Sinja

  sinja do |c|
    # ..
  end

  # ..

  sinja.freeze
end
```

### Code Organization

Sinatra applications might grow overly large with a block for each resource. I
am still working on a better way to handle this (as well as a way to provide
standalone resource controllers for e.g. cloud functions), but for the time
being you can store each resource block as its own proc, and pass it to the
`resource` keyword in lieu of a block. The migration to some future solution
should be relatively painless. For example:

```ruby
# controllers/foo_controller.rb
FooController = proc do
  index do
    Foo.all
  end

  show do |id|
    Foo[id.to_i]
  end

  # ..
end

# app.rb
require 'sinatra/base'
require 'sinatra/jsonapi'

require_relative 'controllers/foo_controller'

class App < Sinatra::Base
  register Sinatra::JSONAPI

  resource :foos, FooController

  freeze_jsonapi
end
```

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
[21]: http://www.sinatrarb.com/contrib/namespace.html
[22]: http://jsonapi.org/format/#document-resource-identifier-objects
