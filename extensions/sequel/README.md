# Sinja::Sequel

<!--
  Title: Sinja::Sequel
  Description: Sequel-specific Helpers and DSL for Sinja
  Author: Mike Pastore
  Keywords: Ruby, Sinatra, Sinatra::JSONAPI, Sinja, Sequel
  -->

[![Gem Version](https://badge.fury.io/rb/sinja-sequel.svg)](https://badge.fury.io/rb/sinja-sequel)

Sinja::Sequel configures your [Sinja][1] application to work with [Sequel][2]
out of the box, and provides additional helpers to greatly simplify the process
of writing the more complex action helpers (specifically `replace`, `merge`,
and `subtract`). An optional extension enhances Sinja's DSL to generate basic
action helpers that can be overridden, customized, or removed.

The core configuration and helpers are in pretty good shape (Sinja uses them in
its [demo app][3] and test suite), but the extension could use some fleshing
out. Testers and community contributions welcome!

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Installation](#installation)
- [Usage](#usage)
  - [Core](#core)
  - [Helpers](#helpers)
    - [`next_pk`](#next_pk)
    - [`add_missing`](#add_missing)
    - [`remove_present`](#remove_present)
    - [`add_remove`](#add_remove)
  - [Extension](#extension)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sinja-sequel'
```

And then execute:

```sh
$ bundle
```

Or install it yourself as:

```sh
$ gem install sinja-sequel
```

## Usage

Always return Sequel datasets (instead of arrays of objects) from your `index`
(e.g. `Foo.dataset`) and `fetch` (e.g.  `resource.bars_dataset`) action
helpers. The `finalize` helper, described below, will ensure they are
"rasterized" before being passed to [JSONAPI::Serializers][5].

You'll want to enable Sequel's `:tactical_eager_loading` plugin for the best
performance with JSONAPI::Serializers. I've [seen][6] it reduce complex
serializations by a factor of 100 (i.e. quite literally one query instead of
100).

If you want to use client-generated IDs, enable the `:update_primary_key`
plugin on the model and call `unrestrict_primary_key` in the model definition
to allow mass assignment (e.g. with `Sequel::Model#set_fields`).

If your model has foreign keys and you want to enforce a non-nullable
constraint at the application level, consider enabling the
`:validation_helpers` plugin on the model and using `validates_not_null` in
conjuction with the `validate!` helper described below:

```ruby
class Bar < Sequel::Model
  plugin :validation_helpers

  def validate
    super
    validates_not_null :foo
  end
end
```

See "Avoding Null Foreign Keys" in the [Sinja][1] documentation for more
information.

Finally, enable the `:pagination` extension on your connection (before
prepending Core) to enable pagination!

### Core

Prepend [Sinja::Sequel::Core](/extensions/sequel/lib/sinja/sequel/core.rb)
after registering Sinja:

```ruby
require 'sinja'
require 'sinja/sequel/core'

class MyApp < Sinatra::Base
  register Sinja

  helpers do
    prepend Sinja::Sequel::Core
  end
end
```

Note that you must use `prepend` (instead of including Sinja::Sequel::Core like
a normal module of Sinatra helpers) in order to ensure that the included
methods take precedence over Sinja's method stubs (e.g. `transaction`).
[This][4] will hopefully be fixed in a future version of Sinatra.

Prepending Core does the following to your application:

* Configures `conflict_`, `not_found_`, and `validation_exceptions`, and
  `validation_formatter`.
* Defines a `database` helper that delegates to `Sequel::Model.db`.
* Defines a `transaction` helper that delegates to `database.transaction`.
* Defines a `validate!` helper that raises an error if `resource` is invalid
  after a `create` or `update` action helper invocation.
* Defines a simple equality-based `filter` helper that passes the filter params
  to `Sequel::Dataset#where`.
* Defines a `sort` helper that applies `Sequel.asc` and `Sequel.desc` to the
  sort terms and passes them to `Sequel::Dataset#order`.
* Defines a `finalize` helper that simply calls `Sequel::Dataset#all`.

If the `:pagination` Sequel extension is loaded, it also does the following:

* Configures `page_using` for page number- and size-based pagination, with an
  additional record count parameter to avoid repetitive `SELECT COUNT` queries
  while paging.
* Defines a `page` helper that calls `Sequel::Dataset#paginate` and computes a
  hash of page params that Sinja will use to construct the root pagination
  links and add to the root metadata of the response.

You may override any of the installed helpers by defining your own. Please see
the [Sinja][1] documentation for more information about Sinja hooks and
configurables, and the [Sequel][2] documentation for more information about
Sequel plugins and features.

### Helpers

Include
[Sinja::Sequel::Helpers](/extensions/sequel/lib/sinja/sequel/helpers.rb) after
registering Sinja:

```ruby
require 'sinja'
require 'sinja/sequel/helpers'

class MyApp < Sinatra::Base
  register Sinja

  helpers Sinja::Sequel::Helpers
end
```

This is the most common use-case. **Note that including Helpers will
automatically prepend Core!**

#### `next_pk`

A convenience method to always return the primary key of the resource and the
resource from your `create` action helpers. Simply use it instead of `next`!

```ruby
create do |attr|
  next_pk Foo.create(attr)
end
```

#### `add_missing`

Take the key of a Sequel \*_to_many association and an array of resource
identifier objects and add the "missing" records to the collection. Makes
writing your `merge` action helpers a breeze!

```ruby
has_many :bars do
  merge do |rios|
    add_missing(:bars, rios)
  end
end
```

It will try to cast the ID of each resource identifier object by sending it the
`:to_i` method; pass in a third argument to specify a different method (e.g. if
the primary key of the `bars` table is a `varchar`, pass in `:to_s` instead).

This helper also takes an optional block that can be used to filter
subresources during processing. Simply return a truthy or falsey value from the
block (or raise an error to abort the entire transaction):

```ruby
has_many :bars do
  merge do |rios|
    add_missing(:bars, rios) do |bar|
      role?(:admin) || bar.owner == resource.owner
    end
  end
end
```

#### `remove_present`

Like `add_missing`, but removes the "present" records from the collection.
Makes writing your `subtract` action helpers a breeze!

#### `add_remove`

Like `add_missing` and `remove_present`, but performs an efficient delta
operation on the collection. Makes writing your `replace` action helpers a
breeze!

### Extension

Register [Sinja::Sequel](/extensions/sequel/lib/sinja/sequel.rb) after
registering Sinja:

```ruby
require 'sinja'
require 'sinja/sequel'

class MyApp < Sinatra::Base
  register Sinja
  register Sinja::Sequel
end
```

**Note that registering the extension will automatically include Helpers!**

After registering the extension, the `resource`, `has_many`, and `has_one` DSL
keywords will generate basic action helpers. The default `create` action helper
does not support client-generated IDs. These action helpers can be subsequently
overridden, customized by setting action helper options (i.e. `:roles`) and/or
defining `before_<action>` hooks, or removed entirely with `remove_<action>`.

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

[1]: https://github.com/mwpastore/sinja
[2]: http://sequel.jeremyevans.net
[3]: https://github.com/mwpastore/sinja/tree/master/demo-app
[4]: https://github.com/sinatra/sinatra/issues/1213
[5]: https://github.com/fotinakis/jsonapi-serializers
[6]: https://github.com/fotinakis/jsonapi-serializers/pull/31#issuecomment-148193366
