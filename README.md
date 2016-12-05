# Sinja (Sinatra::JSONAPI)

[![Gem Version](https://badge.fury.io/rb/sinja.svg)](https://badge.fury.io/rb/sinja)
[![Build Status](https://travis-ci.org/mwpastore/sinja.svg?branch=master)](https://travis-ci.org/mwpastore/sinja)

Sinja is a [Sinatra][1] [extension][10] for quickly building [RESTful][11],
[JSON:API][2]-[compliant][7] web services, leveraging the excellent
[JSONAPI::Serializers][3] gem and [Sinatra::Namespace][21] extension. It
enhances Sinatra's DSL to enable resource-, relationship-, and role-centric
definition of applications, and it configures Sinatra with the proper settings,
MIME-types, filters, conditions, and error-handling to implement JSON:API.
Sinja aims to be lightweight (to the extent that Sinatra is), ORM-agnostic (to
the extent that JSONAPI::Serializers is), and opinionated (to the extent that
the JSON:API specification is).

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
  - [Resource Locator](#resource-locator)
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
  - [Action Helper Hooks &amp; Utilities](#action-helper-hooks-amp-utilities)
  - [Authorization](#authorization)
    - [`default_roles` configurables](#default_roles-configurables)
    - [`:roles` Action Helper option](#roles-action-helper-option)
    - [`role` helper](#role-helper)
  - [Conflicts](#conflicts)
  - [Validations](#validations)
  - [Missing Records](#missing-records)
  - [Transactions](#transactions)
  - [Side-Unloading Related Resources](#side-unloading-related-resources)
  - [Side-Loading Relationships](#side-loading-relationships)
    - [Avoiding Null Foreign Keys](#avoiding-null-foreign-keys)
      - [Many-to-One](#many-to-one)
      - [One-to-Many](#one-to-many)
      - [Many-to-Many](#many-to-many)
  - [Coalesced Find Requests](#coalesced-find-requests)
  - [Patchless Clients](#patchless-clients)
  - [Sinja or Sinatra::JSONAPI](#sinja-or-sinatrajsonapi)
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
all other JSON:API endpoints returning 404 or 405):

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
* To-one and to-many relationships and related resources
* Side-loaded relationships on resource creation and update
* Error-handling
  * Conflicts (constraint violations)
  * Missing records
  * Validation failures
* Filtering, sorting, and paging collections
* Plus all the features of JSONAPI::Serializers!

Its main competitors in the Ruby space are [ActiveModelSerializers][12] (AMS)
with the JsonApi adapter, [JSONAPI::Resources][8] (JR), and
[jsonapi-utils][26], all of which are designed to work with [Rails][16] and
[ActiveRecord][17]/[ActiveModel][18] (although they may work with [Sequel][13]
via [sequel-rails][14] and Sequel's [`:active_model` plugin][15]). Otherwise,
you might use something like Sinatra, [Roda][20], or [Grape][19] with
JSONAPI::Serializers (or another (de)serialization library), your own routes,
and a ton of boilerplate. The goal of this extension is to provide most or all
of the boilerplate for a Sintara application and automate the drawing of routes
based on the resource definitions.

### Extensibility

The "power" of implementing this functionality as a Sinatra extension is that
all of Sinatra's usual features are available within your resource definitions.
The action helpers blocks get compiled into Sinatra helpers, and the
`resource`, `has_one`, and `has_many` keywords build [Sinatra::Namespace][21]
blocks. You can manage caching directives, set headers, and even `halt` (or
`not_found`, although such cases are usually handled transparently by returning
`nil` values or empty collections from action helpers) as desired.

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

    show do |id|
      book = find(id)
      not_found "Book #{id} not found!" unless book
      headers 'X-ISBN'=>book.isbn
      last_modified book.updated_at
      next book, include: %w[author]
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

#### Public APIs

**can?**
: Takes the symbol of an action helper and returns true if the current user has
  access to call that action helper for the current resource using the `role`
  helper and role definitions detailed under "Authorization" below.

**data**
: Returns the `data` key of the deserialized request payload (with symbolized
  names).

**dedasherize**
: Takes a string or symbol and returns the string or symbol with any and all
  dashes transliterated to underscores.

**dedasherize_names**
: Takes a hash and returns the hash with its keys dedasherized (deeply).

**role?**
: Takes a list of role(s) and returns true if it has members in common with the
  current user's role(s).

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

**sideloaded?**
: Returns true if the request was invoked from another action helper.

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
| Authorization   | [Pundit][9]                  | Role-based                                        |
| Immutability    | `immutable` method           | Omit mutator action helpers (e.g. `update`)       |
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
you normally would, define `resource` blocks with action helpers and `has_one`
and `has_many` relationship blocks (with their own action helpers). Sinja will
draw and enable the appropriate routes based on the defined resources,
relationships, and action helpers. Other routes will return the appropriate
HTTP statuses: 403, 404, or 405.

### Configuration

#### Sinatra

Registering this extension has a number of application-wide implications,
detailed below. If you have any non-JSON:API routes, you may want to keep them
in a separate application and incorporate them as middleware or mount them
elsewhere (e.g. with [Rack::URLMap][4]), or host them as a completely separate
web service. It may not be feasible to have custom routes that don't conform to
these settings.

* Registers [Sinatra::Namespace][21] and [Mustermann][25]
* Disables [Rack::Protection][6] (can be reenabled with `enable :protection` or
  by manually `use`-ing the Rack::Protection middleware)
* Disables static file routes (can be reenabled with `enable :static`)
* Disables "classy" error pages (in favor of "classy" JSON:API error documents)
* Adds an `:api_json` MIME-type (`Sinja::MIME_TYPE`)
* Enforces strict checking of the `Accept` and `Content-Type` request headers
* Sets the `Content-Type` response header to `:api_json` (can be overriden with
  the `content_type` helper)
* Normalizes query parameters to reflect the features supported by JSON:API
  (this may be strictly enforced in future versions of Sinja)
* Formats all errors to the proper JSON:API structure
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

  # see "Validations" below
  #c.validation_exceptions = []
  #c.validation_formatter = ->{ [] }

  #c.not_found_exceptions = [] # see "Missing Records" below

  # see "Authorization" below
  #c.default_roles = {}
  #c.default_has_one_roles = {}
  #c.default_has_many_roles = {}

  # Set the error logger used by Sinja
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
`freeze_jsonapi` to freeze the configuration store. You should always freeze
the store after Sinja is configured and all your resources are defined.

### Resource Locator

Much of Sinja's advanced functionality (e.g. updating and destroying resources,
relationship routes) is dependent upon its ability to locate the corresponding
resource for a request. To enable these features, define an ordinary helper
method named `find` in your resource definition that takes a single ID argument
and returns the corresponding object. You can, of course, use this helper
method elsewhere in your application, such as in your `show` action helper.

```ruby
resource :posts
  helpers do
    def find(id)
      Post[id.to_i]
    end
  end

  show do |id|
    next find(id), include: 'comments'
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

  You don't. Instead, control access to the action helpers that use it:
  `update`, `destroy`, and all of the relationship action helpers such as
  `pluck` and `fetch`.

* What happens if I define an action helper that requires a resource locator,
  but no resource locator?

  Sinja will act as if you had not defined the action helper.

As a bit of syntactic sugar, if you define a `find` helper and subsequently
call `show` without a block, Sinja will generate a `show` action helper that
delegates to `find`.

### Action Helpers

Action helpers should be defined within the appropriate block contexts
(`resource`, `has_one`, or `has_many`) using the given keywords and arguments
below. Implicitly return the expected values as described below (as an array if
necessary) or use the `next` keyword (instead of `return` or `break`) to exit
the action helper. Return values marked with a question mark below may be
omitted entirely. Any helper may additionally return an options hash to pass
along to JSONAPI::Serializer.serialize (which will be merged into the global
`serializer_opts` described above). The `:include` (see "Side-Unloading
Related Resources" below) and `:fields` query parameters are automatically
passed through to JSONAPI::Serializers.

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

Take an ID and return the corresponding object (or `nil` if not found) to
serialize on the response.

##### `create {|attr, id| ..}` => id, Object?

With client-generated IDs: Take a hash of (dedasherized) attributes and a
client-generated ID, create a new resource, and return the ID and optionally
the created resource. (Note that only one or the other `create` action helpers
is allowed in any given resource block.)

##### `create {|attr| ..}` => id, Object

Without client-generated IDs: Take a hash of (dedasherized) attributes, create
a new resource, and return the server-generated ID and the created resource.
(Note that only one or the other `create` action helpers is allowed in any
given resource block.)

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

### Action Helper Hooks &amp; Utilities

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

  next find(id), exclude: exclude
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

  create(roles: :user) { |attr| .. }
  update(roles: :owner) { |attr| .. }
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
routes. Let's look at this example request from the JSON:API specification:

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

`create` and `update` are the only two action helpers that trigger sideloading;
`graft`, `merge`, and `clear` are the only action helpers invoked by
sideloading.  You must indicate which combinations are valid using the
`:sideload_on` action helper option. (Note that if you want to sideload `merge`
on `update`, you must define a `clear` action helper as well.) For example:

```ruby
resource :photos do
  helpers do
    def find(id) ..; end
  end

  create { |attr| .. }
  update { |attr| .. }

  has_one :photographer do
    # Allow `create' to sideload the Photographer
    graft(sideload_on: :create) { |rio| .. }
  end

  has_many :tags do
    # Allow `create' and `update' to sideload Tags
    merge(sideload_on: [:create, :update]) { |rios| .. }

    # Allow `update' to clear Tags before sideloading them
    clear(sideload_on: :update) { .. }
  end
end
```

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
involving the `create` and `update` action helpers (and any dependent `graft`
and `merge` action helpers), so this deferred validation pattern is only
appropriate in those cases. You must use immedate validation in all other
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

If your JSON:API client coalesces find requests, the `show` action helper will
be invoked once for each ID in the `:id` filter, and the resulting collection
will be serialized on the response. Both query parameter syntaxes for arrays
are supported: `?filter[id]=1,2` and `?filter[id][]=1&filter[id][]=2`. If any
ID is not found (i.e. `show` returns `nil`), the route will halt with HTTP
status 404.

### Patchless Clients

JSON:API [recommends][23] supporting patchless clients by using the
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

### Sinja or Sinatra::JSONAPI

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
`resource` keyword in lieu of a block. The migration to some future solution
should be relatively painless. For example:

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
[23]: http://jsonapi.org/recommendations/#patchless-clients
[24]: http://www.rubydoc.info/github/rack/rack/Rack/MethodOverride
[25]: http://www.sinatrarb.com/mustermann/
[26]: https://github.com/tiagopog/jsonapi-utils
