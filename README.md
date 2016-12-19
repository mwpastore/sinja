# Sinja (Sinatra::JSONAPI)

<!--
  Title: Sinja
  Description: RESTful, {json:api}-compliant web services in Sinatra
  Author: Mike Pastore
  Keywords: JSON, API, JSONAPI, JSON:API, {json:api}, Ruby, Sinatra, JSONAPI::Serializers, jsonapi-serializers
  -->

[![Gem Version](https://badge.fury.io/rb/sinja.svg)](https://badge.fury.io/rb/sinja)
[![Dependency Status](https://gemnasium.com/badges/github.com/mwpastore/sinja.svg)](https://gemnasium.com/github.com/mwpastore/sinja)
[![Build Status](https://travis-ci.org/mwpastore/sinja.svg?branch=master)](https://travis-ci.org/mwpastore/sinja)
[![{json:api} version](https://img.shields.io/badge/%7Bjson%3Aapi%7D%20version-1.0-lightgrey.svg)][7]
[![Chat in #sinja-rb on Gitter](https://badges.gitter.im/sinja-rb/Lobby.svg)](https://gitter.im/sinja-rb/Lobby)

Sinja is a [Sinatra][1] [extension][10] for quickly building [RESTful][11],
[{json:api}][2]-compliant web services, leveraging the excellent
[JSONAPI::Serializers][3] gem for payload serialization. It enhances Sinatra's
DSL to enable resource-, relationship-, and role-centric API development, and
it configures Sinatra with the proper settings, MIME-types, filters,
conditions, and error-handling.

There are [many][31] parsing (deserializing), rendering (serializing), and
other "JSON API" libraries available for Ruby, but relatively few that attempt
to correctly implement the entire {json:api} specification, including routing,
request header and query parameter checking, and relationship side-loading.
Sinja lets you focus on the business logic of your applications without
worrying about the specification, and without pulling in a heavy framework like
[Rails][16]. It's lightweight, ORM-agnostic, and [Ember.js][32]-friendly!

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Synopsis](#synopsis)
- [Installation](#installation)
- [Ol' Blue Eyes is Back](#ol-blue-eyes-is-back)
- [Basic Usage](#basic-usage)
  - [Configuration](#configuration)
    - [Sinatra](#sinatra)
    - [Sinja](#sinja)
  - [Resource Locators](#resource-locators)
  - [Action Helpers](#action-helpers)
    - [`resource`](#resource)
    - [`has_one`](#has_one)
    - [`has_many`](#has_many)
- [Advanced Usage](#advanced-usage)
  - [Action Helper Hooks & Utilities](#action-helper-hooks--utilities)
  - [Authorization](#authorization)
    - [`default_roles` configurables](#default_roles-configurables)
    - [`:roles` Action Helper option](#roles-action-helper-option)
    - [`role` helper](#role-helper)
  - [Query Parameters](#query-parameters)
  - [Working with Collections](#working-with-collections)
    - [Filtering](#filtering)
    - [Sorting](#sorting)
    - [Paging](#paging)
    - [Finalizing](#finalizing)
  - [Conflicts](#conflicts)
  - [Validations](#validations)
  - [Missing Records](#missing-records)
  - [Transactions](#transactions)
  - [Side-Unloading Related Resources](#side-unloading-related-resources)
  - [Side-Loading Relationships](#side-loading-relationships)
    - [Avoiding Null Foreign Keys](#avoiding-null-foreign-keys)
  - [Coalesced Find Requests](#coalesced-find-requests)
  - [Patchless Clients](#patchless-clients)
- [Extensions](#extensions)
  - [Sequel](#sequel)
- [Application Concerns](#application-concerns)
  - [Performance](#performance)
  - [Public APIs](#public-apis)
    - [Commonly Used](#commonly-used)
    - [Less-Commonly Used](#less-commonly-used)
  - [Sinja or Sinatra::JSONAPI](#sinja-or-sinatrajsonapi)
  - [Code Organization](#code-organization)
  - [Testing](#testing)
- [Comparison with JSONAPI::Resources](#comparison-with-jsonapiresources)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Synopsis

```ruby
require 'sinatra/jsonapi'

resource :posts do
  show do |id|
    Post[id.to_i]
  end

  index do
    Post.all
  end

  create do |attr|
    Post.create(attr)
  end
end

freeze_jsonapi
```

Assuming the presence of a `Post` model and serializer, running the above
"classic"-style Sinatra application would enable the following endpoints (with
all other {json:api} endpoints returning 404 or 405):

* `GET /posts/<id>`
* `GET /posts`
* `POST /posts`

The resource locator and other action helpers, documented below, enable other
endpoints.

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

Please see the [demo-app](/demo-app) for a more complete example.

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

## Ol' Blue Eyes is Back

The "power" so to speak of implementing this functionality as a Sinatra
extension is that all of Sinatra's usual features are available within your
resource definitions. Action helper blocks get compiled into Sinatra helpers,
and the `resource`, `has_one`, and `has_many` keywords build
[Sinatra::Namespace][21] blocks. You can manage caching directives, set
headers, and even `halt` (or `not_found`, although such cases are usually
handled transparently by returning `nil` values or empty collections from
action helpers) as appropriate.

```ruby
class App < Sinatra::Base
  register Sinatra::JSONAPI

  # <- This is a Sinatra::Base class definition. (Duh.)

  resource :books do
    # <- This is a Sinatra::Namespace block.

    show do |id|
      # <- This is a "special" Sinatra helper, scoped to the resource namespace.
    end

    has_one :author do
      # <- This is a Sinatra::Namespace block, nested under the resource namespace.

      pluck do
        # <- This is a "special" Sinatra helper, scoped to the nested namespace.
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
    cache_control :public, max_age: 3_600
  end

  # define a custom /status route
  get('/status', provides: :json) { 'OK' }

  resource :books do
    helpers do
      def find(id)
        Book[id.to_i]
      end
    end

    show do
      headers 'X-ISBN'=>resource.isbn
      last_modified resource.updated_at
      next resource, include: %w[author]
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
      halt 403 unless can?(:index) # restrict access to those with index rights

      serialize_models Book.where{}.reverse_order(:recent_sales).limit(10).all
    end
  end

  freeze_jsonapi
end
```

## Basic Usage

You'll need a database schema and models (using the engine and ORM of your
choice) and [serializers][3] to get started. Create a new Sinatra application
(classic or modular) to hold all your {json:api} controllers and (if modular)
register this extension. Instead of defining routes with `get`, `post`, etc. as
you normally would, define `resource` blocks with action helpers and `has_one`
and `has_many` relationship blocks (with their own action helpers). Sinja will
draw and enable the appropriate routes based on the defined resources,
relationships, and action helpers. Other routes will return the appropriate
HTTP statuses: 403, 404, or 405.

### Configuration

#### Sinatra

Registering this extension has a number of application-wide implications,
detailed below. If you have any non-{json:api} routes, you may want to keep them
in a separate application and incorporate them as middleware or mount them
elsewhere (e.g. with [Rack::URLMap][4]), or host them as a completely separate
web service. It may not be feasible to have custom routes that don't conform to
these settings.

* Registers [Sinatra::Namespace][21] and [Mustermann][25]
* Disables [Rack::Protection][6] (can be reenabled with `enable :protection` or
  by manually `use`-ing the Rack::Protection middleware)
* Disables static file routes (can be reenabled with `enable :static`; be sure
  to reenable Rack::Protection::PathTraversal as well)
* Disables "classy" error pages (in favor of "classy" {json:api} error documents)
* Adds an `:api_json` MIME-type (`application/vnd.api+json`)
* Enforces strict checking of the `Accept` and `Content-Type` request headers
* Sets the `Content-Type` response header to `:api_json` (can be overriden with
  the `content_type` helper)
* Normalizes and strictly enforces query parameters to reflect the features
  supported by {json:api}
* Formats all errors to the proper {json:api} structure
* Serializes all response bodies (including errors) to JSON
* Modifies `halt` and `not_found` to raise exceptions instead of just setting
  the status code and body of the response

#### Sinja

Sinja provides its own configuration store that can be accessed through the
`configure_jsonapi` block. The following configurables are available (with
their defaults shown):

```ruby
configure_jsonapi do |c|
  #c.conflict_exceptions = [] # see "Conflicts" below

  #c.not_found_exceptions = [] # see "Missing Records" below

  # see "Validations" below
  #c.validation_exceptions = []
  #c.validation_formatter = ->{ [] }

  # see "Authorization" below
  #c.default_roles = {}
  #c.default_has_one_roles = {}
  #c.default_has_many_roles = {}

  # You can't set this directly; see "Query Parameters" below
  #c.query_params = {
  #  :include=>Array, :fields=>Hash, :filter=>Hash, :page=>Hash, :sort=>Array
  #}

  #c.page_using = {} # see "Paging" below

  # Set the error logger used by Sinja (set to `nil' to disable)
  #c.error_logger = ->(error_hash) { logger.error('sinja') { error_hash } }

  # A hash of options to pass to JSONAPI::Serializer.serialize
  #c.serializer_opts = {}

  # JSON methods to use when serializing response bodies and errors
  #c.json_generator = development? ? :pretty_generate : :generate
  #c.json_error_generator = development? ? :pretty_generate : :generate
end
```

The above structures are mutable (e.g. you can do `c.conflict_exceptions <<
FooError` and `c.serializer_opts[:meta] = { foo: 'bar' }`) until you call
`freeze_jsonapi` to freeze the configuration store. **You should always freeze
the store after Sinja is configured and all your resources are defined.**

### Resource Locators

Much of Sinja's advanced functionality (e.g. updating and destroying resources,
relationship routes) is dependent upon its ability to locate the corresponding
resource for a request. To enable these features, define an ordinary helper
method named `find` in your resource definition that takes a single ID argument
and returns the corresponding object. Once defined, a `resource` object will be
made available in any action helpers that operate on a single (parent)
resource.

```ruby
resource :posts do
  helpers do
    def find(id)
      Post[id.to_i]
    end
  end

  show do
    next resource, include: 'comments'
  end
end
```

* What's the difference between `find` and `show`?

  You can think of it as the difference between a Model and a View: `find`
  retrieves the record, `show` presents it.

* Why separate the two? Why not use `show` as the resource locator?

  For a variety of reasons, but primarily because the access rights for viewing
  a resource are not always the same as those for updating and/or destroying a
  resource, and vice-versa. For example, a user may be able to delete a
  resource or subtract a relationship link without being able to see the
  resource or its relationship linkage.

* How do I control access to the resource locator?

  You don't. Instead, control access to the action helpers that use it: `show`,
  `update`, `destroy`, and all of the relationship action helpers such as
  `pluck` and `fetch`.

* What happens if I define an action helper that requires a resource locator,
  but no resource locator?

  Sinja will act as if you had not defined the action helper.

As a bit of syntactic sugar, if you define a `find` helper and subsequently
call `show` without a block, Sinja will generate a `show` action helper that
simply returns `resource`.

### Action Helpers

Action helpers should be defined within the appropriate block contexts
(`resource`, `has_one`, or `has_many`) using the given keywords and arguments
below. Implicitly return the expected values as described below (as an array if
necessary) or use the `next` keyword (instead of `return` or `break`) to exit
the action helper. Return values marked with a question mark below may be
omitted entirely. Any helper may additionally return an options hash to pass
along to JSONAPI::Serializer.serialize (which will be merged into the global
`serializer_opts` described above). The `:include` (see "Side-Unloading Related
Resources" below) and `:fields` (for sparse fieldsets) query parameters are
automatically passed through to JSONAPI::Serializers.

All arguments to action helpers are "tainted" and should be treated as
potentially dangerous: IDs, attribute hashes, and (arrays of) [resource
identifier object][22] hashes.

Finally, some routes will automatically invoke the resource locator on your
behalf and make the selected resource available to the corresponding action
helper(s) as `resource`. For example, the `PATCH /<name>/:id` route looks up
the resource with that ID using the `find` resource locator and makes it
available to the `update` action helper as `resource`. The same goes for the
`DELETE /<name>/:id` route and the `destroy` action helper, and all of the
`has_one` and `has_many` action helpers.

#### `resource`

##### `index {..}` => Array

Return an array of zero or more objects to serialize on the response.

##### `show {|id| ..}` => Object

Without a resource locator: Take an ID and return the corresponding object (or
`nil` if not found) to serialize on the response. (Note that only one or the
other `show` action helpers is allowed in any given resource block.)

##### `show {..}` => Object

With a resource locator: Return the `resource` object to serialize on the
response. (Note that only one or the other `show` action helpers is allowed in
any given resource block.)

##### `show_many {|ids| ..}` => Array

Take an array of IDs and return an equally-lengthed array of objects to
serialize on the response. See "Coalesced Find Requests" below.

##### `create {|attr| ..}` => id, Object

Without client-generated IDs: Take a hash of (dedasherized) attributes, create
a new resource, and return the server-generated ID and the created resource.
(Note that only one or the other `create` action helpers is allowed in any
given resource block.)

##### `create {|attr, id| ..}` => id, Object?

With client-generated IDs: Take a hash of (dedasherized) attributes and a
client-generated ID, create a new resource, and return the ID and optionally
the created resource. (Note that only one or the other `create` action helpers
is allowed in any given resource block.)

##### `update {|attr| ..}` => Object?

Take a hash of (dedasherized) attributes, update `resource`, and optionally
return the updated resource. **Requires a resource locator.**

##### `destroy {..}`

Delete or destroy `resource`. **Requires a resource locator.**

#### `has_one`

**Requires a resource locator.**

##### `pluck {..}` => Object

Return the related object vis-&agrave;-vis `resource` to serialize on the
response.

##### `prune {..}` => TrueClass?

Remove the relationship from `resource`. To serialize the updated linkage on
the response, refresh or reload `resource` (if necessary) and return a truthy
value.

For example, using [Sequel][13]:

```ruby
has_one :qux do
  prune do
    resource.qux = nil
    resource.save_changes # will return truthy if the relationship was present
  end
end
```

##### `graft {|rio| ..}` => TrueClass?

Take a [resource identifier object][22] hash and update the relationship on
`resource`. To serialize the updated linkage on the response, refresh or reload
`resource` (if necessary) and return a truthy value.

#### `has_many`

**Requires a resource locator.**

##### `fetch {..}` => Array

Return an array of related objects vis-&agrave;-vis `resource` to serialize on
the response.

##### `clear {..}` => TrueClass?

Remove all relationships from `resource`. To serialize the updated linkage on
the response, refresh or reload `resource` (if necessary) and return a truthy
value.

For example, using [Sequel][13]:

```ruby
has_many :bars do
  clear do
    resource.remove_all_bars # will return truthy if relationships were present
  end
end
```

##### `replace {|rios| ..}` => TrueClass?

Take an array of [resource identifier object][22] hashes and update
(add/remove) the relationships on `resource`. To serialize the updated linkage
on the response, refresh or reload `resource` (if necessary) and return a
truthy value.

In principle, `replace` should delete all members of the existing collection
and insert all members of a new collection, but in practice&mdash;for
performance reasons, especially with large collections and/or complex
constraints&mdash;it may be prudent to simply apply a delta.

##### `merge {|rios| ..}` => TrueClass?

Take an array of [resource identifier object][22] hashes and update (add unless
already present) the relationships on `resource`. To serialize the updated
linkage on the response, refresh or reload `resource` (if necessary) and return
a truthy value.

##### `subtract {|rios| ..}` => TrueClass?

Take an array of [resource identifier object][22] hashes and update (remove
unless already missing) the relationships on `resource`. To serialize the
updated linkage on the response, refresh or reload `resource` (if necessary)
and return a truthy value.

## Advanced Usage

### Action Helper Hooks & Utilities

You may remove a previously-registered action helper with `remove_<action>`:

```ruby
resource :foos do
  index do
    # ..
  end

  remove_index
end
```

You may invoke an action helper keyword without a block to modify the options
(i.e. roles and sideloading) of a previously-registered action helper while
preseving the existing behavior:

```ruby
resource :bars do
  show do |id|
    # ..
  end

  show(roles: :admin) # restrict the above action helper to the `admin' role
end
```

You may define an ordinary helper method named `before_<action>` (in the
resource or relationship scope or any parent scopes) that takes the same
arguments as the corresponding block:

```ruby
helpers do
  def before_create(attr)
    halt 400 unless valid_key?(attr.delete(:special_key))
  end
end

resource :quxes do
  create do |attr|
    attr.key?(:special_key) # => false
  end
end
```

Any changes made to attribute hashes or (arrays of) resource identifier object
hashes in a `before` hook will be persisted to the action helper.

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

#### `default_roles` configurables

You set the default roles for the entire Sinja application in the top-level
configuration. Action helpers without any default roles are unrestricted by
default.

```ruby
configure_jsonapi do |c|
  # Resource roles
  c.default_roles = {
    index: :user,
    show: :user,
    create: :admin,
    update: :admin,
    destroy: :super
  }

  # To-one relationship roles
  c.default_has_one_roles = {
    pluck: :user,
    prune: :admin,
    graft: :admin
  }

  # To-many relationship roles
  c.default_has_many_roles = {
    fetch: :user,
    clear: :admin,
    replace: :admin,
    merge: :admin,
    subtract: :admin
  }
end
```

#### `:roles` Action Helper option

To override the default roles for any given action helper, specify a `:roles`
option when defining it. To remove all restrictions from an action helper, set
`:roles` to an empty array. For example, to manage access to `show` at
different levels of granularity (with the above default roles):

```ruby
resource :foos do
  show do
    # any logged-in user (with the `user' role) can access /foos/:id
  end
end

resource :bars do
  show(roles: :admin) do
    # only logged-in users with the `admin' role can access /bars/:id
  end
end

resource :quxes do
  show(roles: []) do
    # anyone (bypassing the `role' helper) can access /quxes/:id
  end
end
```

#### `role` helper

Finally, define a `role` helper in your application that returns the user's
role(s) (if any). You can handle login failures in your middleware, elsewhere
in the application (i.e. a `before` filter), or within the helper, either by
raising an error or by letting Sinja raise an error on restricted action
helpers when `role` returns `nil` (the default behavior).

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

If you need more fine-grained control, for example if your action helper logic
varies by the user's role, you can use a switch statement on `role` along with
the `Sinja::Roles` utility class:

```ruby
index(roles: [:user, :admin, :super]) do
  case role
  when Sinja::Roles[:user]
    # logic specific to the `user' role
  when Sinja::Roles[:admin, :super]
    # logic specific to administrative roles
  end
end
```

Or use the `role?` helper:

```ruby
show do |id|
  exclude = []
  exclude << 'secrets' unless role?(:admin)

  next resource, exclude: exclude
end
```

You can append resource- or even relationship-specific roles by defining a
nested helper and calling `super` (keeping in mind that `resource` may be
`nil`).

```ruby
helpers do
  def role
    [:user] if logged_in_user
  end
end

resource :foos do
  helpers do
    def role
      if resource&.owner == logged_in_user
        [*super].push(:owner)
      else
        super
      end
    end
  end

  create(roles: :user) {|attr| .. }
  update(roles: :owner) {|attr| .. }
end
```

Please see the [demo-app](/demo-app) for a more complete example.

### Query Parameters

The {json:api} specification states that any unhandled query parameters should
cause the request to abort with HTTP status 400. To enforce this requirement,
Sinja maintains a global "whitelist" of acceptable query parameters as well as
a per-route whitelist, and interrogates your application to see which features
it supports; for example, a route may generally allow a `filter` query
parameter, but you may not have defined a `filter` helper.

To let a custom query parameter through to the standard action helpers, add it
to the `query_params` configurable with a `nil` value:

```ruby
configure_jsonapi do |c|
  c.query_params[:foo] = nil
end
```

To let a custom route accept standard query parameters, add a `:qparams` route
condition:

```ruby
get '/top10', qparams: [:include, :sort] do
  # ..
end
```

### Working with Collections

#### Filtering

Allow clients to filter the collections returned by the `index` and `fetch`
action helpers by defining a `filter` helper in the appropriate scope that
takes a collection and a hash of `filter` query parameters (with its top-level
keys dedasherized and symbolized) and returns the filtered collection. You may
also set a `:filter_by` option on the action helper to an array of symbols
representing the "filter-able" fields for that resource.

For example, to implement simple equality filters using Sequel:

```ruby
helpers do
  def filter(collection, fields={})
    collection.where(fields)
  end
end

resource :posts do
  index(filter_by: [:title, :type]) do
    Foo # return a Sequel::Dataset (instead of an array of Sequel::Model instances)
  end
end
```

The easiest way to set a default filter is to tweak the post-processed query
parameter(s) in a `before_<action>` hook:

```ruby
resource :posts do
  helpers do
    def before_index
      params[:filter][:type] = 'article' if params[:filter].empty?
    end
  end

  index do
    # ..
  end
end
```

#### Sorting

Allow clients to sort the collections returned by the `index` and `fetch`
action helpers by defining a `sort` helper in the appropriate scope that takes
a collection and a hash of `sort` query parameters (with its top-level keys
dedasherized and symbolized) and returns the sorted collection. The hash values
are either `:asc` (to sort ascending) or `:desc` (to sort descending). You may
also set a `:sort_by` option on the action helper to an array of symbols
representing the "sort-able" fields for that resource.

For example, to implement sorting using Sequel:

```ruby
helpers do
  def sort(collection, fields={})
    collection.order(*fields.map {|k, v| Sequel.send(v, k) })
  end
end

resource :posts do
  index(sort_by: :created_at) do
    Foo # return a Sequel::Dataset (instead of an array of Sequel::Model instances)
  end
end
```

The easiest way to set a default sort order is to tweak the post-processed
query parameter(s) in a `before_<action>` hook:

```ruby
resource :posts do
  helpers do
    def before_index
      params[:sort][:title] = :asc if params[:sort].empty?
    end
  end

  index do
    # ..
  end
end
```

#### Paging

Allow clients to page the collections returned by the `index` and `fetch`
action helpers by defining a `page` helper in the appropriate scope that takes
a collection and a hash of `page` query parameters (with its top-level keys
dedasherized and symbolized) and returns the paged collection along with a
special nested hash used as root metadata and to build the paging links.

The top-level keys of the hash returned by this method must be members of the
set: {`:self`, `:first`, `:prev`, `:next`, `:last`}. The values of the hash are
hashes themselves containing the query parameters used to construct the
corresponding link. For example, the hash:

```ruby
{
  prev: {
    number: 3,
    size: 10
  },
  next: {
    number: 5,
    size: 10
  }
}
```

Could be used to build the following top-level links in the response document:

```json
"links": {
  "prev": "/posts?page[number]=3&page[size]=10",
  "next": "/posts?page[number]=5&page[size]=10"
}
```

You must also set the `page_using` configurable to a hash of symbols
representing the paging fields used in your application (for example, `:number`
and `:size` for the above example) along with their default values (or `nil`).
Please see the [Sequel extension][30] for a detailed, working example.

The easiest way to page a collection by default is to tweak the post-processed
query parameter(s) in a `before_<action>` hook:

```ruby
resource :posts do
  helpers do
    def before_index
      params[:page][:number] = 1 if params[:page].empty?
    end
  end

  index do
    # ..
  end
end
```

#### Finalizing

If you need to perform any additional actions on a collection after it is
filtered, sorted, and/or paged, but before it is serialized, define a
`finalize` helper that takes a collection and returns the finalized collection.
For example, to convert Sequel datasets to arrays of models before
serialization:

```ruby
helpers do
  def finalize(collection)
    collection.all
  end
end
```

### Conflicts

If your database driver raises exceptions on constraint violations, you should
specify which exception class(es) should be handled and return HTTP status 409.

For example, using [Sequel][13]:

```ruby
configure_jsonapi do |c|
  c.conflict_exceptions << Sequel::ConstraintViolation
end
```

### Validations

If your ORM raises exceptions on validation errors, you should specify which
exception class(es) should be handled and return HTTP status 422, along
with a formatter proc that transforms the exception object into an array of
two-element arrays containing the name or symbol of the attribute that failed
validation and the detailed errror message for that attribute.

For example, using [Sequel][13]:

```ruby
configure_jsonapi do |c|
  c.validation_exceptions << Sequel::ValidationFailed
  c.validation_formatter = ->(e) { e.errors.keys.zip(e.errors.full_messages) }
end
```

### Missing Records

If your database driver raises exceptions on missing records, you should
specify which exception class(es) should be handled and return HTTP status 404.
This is particularly useful for relationship action helpers, which don't have
access to a dedicated subresource locator.

For example, using [Sequel][13]:

```ruby
configure_jsonapi do |c|
  c.not_found_exceptions << Sequel::NoMatchingRow
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

For example, using [Sequel][13] with the database handle stored in the constant
`DB`:

```ruby
helpers do
  def transaction
    DB.transaction { yield }
  end
end
```

### Side-Unloading Related Resources

You may pass an `:include` serializer option (which can be either a
comma-delimited string or array of strings) when returning resources from
action helpers. This instructs JSONAPI::Serializers to include a default set of
related resources along with the primary resource. If the client specifies an
`include` query parameter, Sinja will automatically pass it to
JSONAPI::Serializer.serialize, replacing any default value. You may also pass a
Sinja-specific `:exclude` option to prevent certain related resources from
being included in the response. If you exclude a resource, its descendents will
be automatically excluded as well. Feedback welcome.

Sinja will attempt to automatically exclude related resources based on the
current user's role(s) and any available `pluck` and `fetch` action helper
roles. For example, if resource Foo has many Bars and the current user does not
have access to Foo.Bars#fetch, the user will not be able to include Bars. It
will traverse the roles configuration, so if the current user has access to
Foo.Bars#fetch but not Bars.Qux#pluck, the user will be able to include Bars
but not Bars.Qux. This feature is experimental. Note that in contrast to the
`:exclude` option, if a related resource is excluded by this mechanism, its
descendents will _not_ be automatically excluded.

### Side-Loading Relationships

Sinja works hard to DRY up your business logic. As mentioned above, when a
request comes in to create or update a resource and that request includes
relationships, Sinja will try to farm out the work to your defined relationship
routes. Let's look at this example request from the {json:api} specification:

```
POST /photos HTTP/1.1
Content-Type: application/vnd.api+json
Accept: application/vnd.api+json
```

```json
{
  "data": {
    "type": "photos",
    "attributes": {
      "title": "Ember Hamster",
      "src": "http://example.com/images/productivity.png"
    },
    "relationships": {
      "photographer": {
        "data": { "type": "people", "id": "9" }
      }
    }
  }
}
```

Assuming a `:photos` resource with a `has_one :photographer` relationship in
the application, and `graft` is configured to sideload on `create` (more on
this in a moment), Sinja will invoke the following action helpers in turn:

1. `create` on the Photos resource (with `data.attributes`)
1. `graft` on the Photographer relationship (with
    `data.relationships.photographer.data`)

If any step of the process fails&mdash;for example, if the `graft` action
helper is not defined in the Photographer relationship, or if it does not
permit sideloading from `create`, or if it raises an error&mdash;the entire
request will fail and any database changes will be rolled back (given a
`transaction` helper). Note that the user's role must grant them access to call
either `graft` or `create`.

`create` and `update` are the resource action helpers that trigger sideloading;
`graft` and `prune` are the to-one action helpers invoked by sideloading; and
`replace`, `merge`, and `clear` are the to-many action helpers invoked by
sideloading. You must indicate which combinations are valid using the
`:sideload_on` action helper option. For example:

```ruby
resource :photos do
  helpers do
    def find(id) ..; end
  end

  create {|attr| .. }

  has_one :photographer do
    # Allow `create' to sideload Photographer
    graft(sideload_on: :create) {|rio| .. }
  end

  has_many :tags do
    # Allow `create' to sideload Tags
    merge(sideload_on: :create) {|rios| .. }
  end
end
```

The following matrix outlines which combinations of action helpers and
`:sideload_on` options enable which behaviors:

<table>
<thead>
<tr>
  <th rowspan="2">Desired behavior</th>
  <th colspan="2">For to-one relationship(s)</th>
  <th colspan="2">For to-many relationship(s)</th>
</tr>
<tr>
  <th>Define Action Helper</th>
  <th>With <code>:sideload_on</code></th>
  <th>Define Action Helper</th>
  <th>With <code>:sideload_on</code></th>
</tr>
</thead>
<tbody>
<tr>
  <td>Set relationship(s) when creating resource</td>
  <td><code>graft</code></td>
  <td><code>:create</code></td>
  <td><code>merge</code></td>
  <td><code>:create</code></td>
</tr>
<tr>
  <td>Set relationship(s) when updating resource</td>
  <td><code>graft</code></td>
  <td><code>:update</code></td>
  <td><code>replace</code></td>
  <td><code>:update</code></td>
</tr>
<tr>
  <td>Delete relationship(s) when updating resource</td>
  <td><code>prune</code></td>
  <td><code>:update</code></td>
  <td><code>clear</code></td>
  <td><code>:update</code></td>
</tr>
</tbody>
</table>

#### Avoiding Null Foreign Keys

Now, let's say our DBA is forward-thinking and wants to make the foreign key
constraint between the `photographer_id` column on the Photos table and the
People table non-nullable. Unfortunately, that will break Sinja, because the
Photo will be inserted first, with a null Photographer. (Deferrable constraints
would be a perfect solution to this problem, but `NOT NULL` constraints are not
deferrable in Postgres, and constraints in general are not deferrable in
MySQL.)

Instead, we'll need to enforce our non-nullable relationships at the
application level. To accomplish this, define an ordinary helper named
`validate!` (in the resource scope or any parent scopes). This method, if
present, is invoked from within the transaction after the entire request has
been processed, and so can abort the transaction (following your ORM's
semantics). For example:

```ruby
resource :photos do
  helpers do
    def validate!
      fail 'Invalid Photographer for Photo' if resource.photographer.nil?
    end
  end
end
```

If your ORM supports validation&mdash;and "deferred validation"&mdash;you can
easily handle all such situations (as well as other types of validations) at
the top-level of your application. (Make sure to define your validation
exceptions and formatter as described above.) For example, using [Sequel][13]:

```ruby
class Photo < Sequel::Model
  many_to_one :photographer

  # http://sequel.jeremyevans.net/rdoc/files/doc/validations_rdoc.html
  def validate
    super
    errors.add(:photographer, 'cannot be null') if photographer.nil?
  end
end

helpers do
  def validate!
    raise Sequel::ValidationFailed, resource.errors unless resource.valid?
  end
end

resource :photos do
  create do |attr|
    photo = Photo.new
    photo.set(attr)
    photo.save(validate: false) # defer validation
  end

  has_one :photographer do
    graft(sideload_on: :create) do |rio|
      resource.photographer = People.with_pk!(rio[:id].to_i)
      resource.save_changes(validate: !sideloaded?) # defer validation if sideloaded
    end
  end
end
```

Note that the `validate!` hook is _only_ invoked from within transactions
involving the `create` and `update` action helpers (and any action helpers
invoked via the sideloading mechanism), so this deferred validation pattern is
only appropriate in those cases. You must use immedate validation in all other
cases. The `sideloaded?` helper is provided to help disambiguate edge cases.

> TODO: The following three sections are a little confusing. Rewrite them.

##### Many-to-One

Example: Photo belongs to (has one) Photographer; Photo.Photographer cannot be
null.

* Don't define `prune` relationship action helper
* Define `graft` relationship action helper to enable reassigning the Photographer
* Define `destroy` resource action helper to enable removing the Photo
* Use `validate!` helper to check for nulls

##### One-to-Many

Example: Photographer has many Photos; Photo.Photographer cannot be null.

* Don't define `clear` relationship action helper
* Don't define `subtract` relationship action helper
* Delegate removing Photos and reassigning Photographers to Photo resource

##### Many-to-Many

Example: Photo has many Tags.

Nothing to worry about here! Feel free to use `NOT NULL` foreign key
constraints on the join table.

### Coalesced Find Requests

If your {json:api} client coalesces find requests, the resource locator (or
`show` action helper) will be invoked once for each ID in the `:id` filter, and
the resulting collection will be serialized on the response. Both query
parameter syntaxes for arrays are supported: `?filter[id]=1,2` and
`?filter[id][]=1&filter[id][]=2`. If any ID is not found (i.e. `show` returns
`nil`), the route will halt with HTTP status 404.

Optionally, to reduce round trips to the database, you may define a "special"
`show_many` action helper that takes an array of IDs to show. It does not take
`:roles` or any other options and will only be invoked if the current user has
access to `show`. This feature is experimental.

Collections assembled during coalesced find requests will not be filtered,
sorted, or paged. The easiest way to limit the number of records that can be
queried is to define a `show_many` action helper and validate the length of the
passed array in the `before_show_many` hook:

```ruby
resource :foos do
  helpers do
    def before_show_many(ids)
      halt 413, 'You want the impossible.' if ids.length > 50
    end
  end

  show_many do |ids|
    # ..
  end
end
```

### Patchless Clients

{json:api} [recommends][23] supporting patchless clients by using the
`X-HTTP-Method-Override` request header to coerce a `POST` into a `PATCH`. To
support this in Sinja, add the Sinja::MethodOverride middleware (which is a
stripped-down version of [Rack::MethodOverride][24]) into your application (or
Rackup configuration):

```ruby
require 'sinja'
require 'sinja/method_override'

class MyApp < Sinatra::Base
  use Sinja::MethodOverride

  register Sinja

  # ..
end
```

## Extensions

Sinja extensions provide additional helpers, DSL, and ORM-specific boilerplate
as separate gems. Community contributions welcome!

### Sequel

Please see [Sinja::Sequel][30] for more information.

## Application Concerns

### Performance

Although there is some heavy metaprogramming happening at boot time, the end
result is simply a collection of Sinatra namespaces, routes, filters,
conditions, helpers, etc., and Sinja applications should perform as if you had
written them verbosely. The main caveat is that there are quite a few block
closures, which don't perform as well as normal methods in Ruby. Feedback
welcome.

### Public APIs

Sinja makes a few APIs public to help you work around edge cases in your
application.

#### Commonly Used

**can?**
: Takes the symbol of an action helper and returns true if the current user has
  access to call that action helper for the current resource using the `role`
  helper and role definitions detailed under "Authorization" below.

**role?**
: Takes a list of role(s) and returns true if it has members in common with the
  current user's role(s).

**sideloaded?**
: Returns true if the request was invoked from another action helper.

#### Less-Commonly Used

These are helpful if you want to add some custom routes to your Sinja
application.

**data**
: Returns the `data` key of the deserialized request payload (with symbolized
  names).

**dedasherize**
: Takes a string or symbol and returns the string or symbol with any and all
  dashes transliterated to underscores, and camelCase converted to snake_case.

**dedasherize_names**
: Takes a hash and returns the hash with its keys dedasherized (deeply).

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

### Sinja or Sinatra::JSONAPI

Everything is dual-namespaced under both Sinatra::JSONAPI and Sinja, and Sinja
requires Sinatra::Base, so this:

```ruby
require 'sinatra/base'
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

Can also be written like this ("modular"-style applications only):

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

Sinja applications might grow overly large with a block for each resource. I am
still working on a better way to handle this (as well as a way to provide
standalone resource controllers for e.g. cloud functions), but for the time
being you can store each resource block as its own Proc, and pass it to the
`resource` keyword as a block. The migration to some future solution should be
relatively painless. For example:

```ruby
# controllers/foo_controller.rb
FooController = proc do
  show do |id|
    Foo[id.to_i]
  end

  index do
    Foo.all
  end

  # ..
end

# app.rb
require 'sinatra/base'
require 'sinatra/jsonapi'

require_relative 'controllers/foo_controller'

class App < Sinatra::Base
  register Sinatra::JSONAPI

  resource :foos, &FooController

  freeze_jsonapi
end
```

### Testing

The short answer to "How do I test my Sinja application?" is "Like you would
any other Sinatra application." Unfortunately, the testing story isn't quite
*there* yet for Sinja. I think leveraging something like [Munson][27] or
[json_api_client][28] is probably the best bet for integration testing, but
unfortunately both projects are rife with broken and/or missing critical
features. And until we can solve the general code organization problem (most
likely with patches to Sinatra), it will remain difficult to isolate action
helpers and other artifacts for unit testing.

Sinja's own test suite is based on [Rack::Test][29] (plus some ugly kludges).
I wouldn't recommend it but it might be a good place to start looking for
ideas. It leverages the [demo-app](/demo-app) with Sequel and an in-memory
database to perform integration testing of Sinja's various features under
MRI/YARV and JRuby. The goal is to free you from worrying about whether your
applications will behave according to the {json:api} spec (as long as you
follow the usage documented in this README) and focus on testing your business
logic.

## Comparison with JSONAPI::Resources

| Feature         | JR                               | Sinja                                             |
| :-------------- | :------------------------------- | :------------------------------------------------ |
| Serializer      | Built-in                         | [JSONAPI::Serializers][3]                         |
| Framework       | Rails                            | Sinatra, but easy to mount within others          |
| Routing         | ActionDispatch::Routing          | Mustermann                                        |
| Caching         | ActiveSupport::Cache             | BYO                                               |
| ORM             | ActiveRecord/ActiveModel         | BYO                                               |
| Authorization   | [Pundit][9]                      | Role-based                                        |
| Immutability    | `immutable` method               | Omit mutator action helpers (e.g. `update`)       |
| Fetchability    | `fetchable_fields` method        | Omit attributes in Serializer                     |
| Creatability    | `creatable_fields` method        | Handle in `create` action helper or Model\*       |
| Updatability    | `updatable_fields` method        | Handle in `update` action helper or Model\*       |
| Sortability     | `sortable_fields` method         | `sort` helper and `:sort_by` option               |
| Default sorting | `default_sort` method            | Set default for `params[:sort]`                   |
| Context         | `context` method                 | Rack middleware (e.g. `env['context']`)           |
| Attributes      | Define in Model and Resource     | Define in Model\* and Serializer                  |
| Formatting      | `:format` attribute keyword      | Define attribute as a method in Serialier         |
| Relationships   | Define in Model and Resource     | Define in Model, Resource, and Serializer         |
| Filters         | `filter(s)` keywords             | `filter` helper and `:filter_by` option           |
| Default filters | `:default` filter keyword        | Set default for `params[:filter]`                 |
| Pagination      | JSONAPI::Paginator               | `page` helper and `page_using` configurable       |
| Meta            | `meta` method                    | Serializer `:meta` option               |
| Primary keys    | `resource_key_type` configurable | Serializer `id` method               |

\* &ndash; Depending on your ORM.

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
[7]: http://jsonapi.org/format/1.0/
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
[23]: http://jsonapi.org/recommendations/#patchless-clients
[24]: http://www.rubydoc.info/github/rack/rack/Rack/MethodOverride
[25]: http://www.sinatrarb.com/mustermann/
[26]: https://jsonapi-suite.github.io/jsonapi_suite/
[27]: https://github.com/coryodaniel/munson
[28]: https://github.com/chingor13/json_api_client
[29]: https://github.com/brynary/rack-test
[30]: https://github.com/mwpastore/sinja-sequel
[31]: http://jsonapi.org/implementations/#server-libraries-ruby
[32]: http://emberjs.com
