## Demo App

This is the demo app for Sinja, used as an example of and for testing Sinja. It
is a very simplistic blog-like application with database tables, models,
serializers, and controllers for authors, posts, comments, and tags. It uses
[Sequel ORM](http://sequel.jeremyevans.net) (and the [Sequel
helpers](/lib/sinja/helpers/sequel.rb) provided with Sinja) with an in-memory
SQLite database, and it works under both MRI/YARV 2.3+ and JRuby 9.1+.

### Usage

Assuming you have a working, Bundler-enabled Ruby environment, simply clone
this repo, `cd` into the `demo-app` subdirectory, and run the following
commands:

```
$ bundle install
$ bundle exec ruby app.rb [-p <PORT>]
```

The web server will report the port it's listening on, or you can specify a
port with the `-p` option. It will respond to JSON:API-compliant requests
(don't forget to set an `Accept` header) to `/authors`, `/posts`, `/comments`,
and `/tags`, although not every endpoint is implemented. Log in by setting the
`X-Email` header on the request to the email address of a registered user; the
default administrator email address is all@yourbase.com.

**This is clearly extremely insecure and should not be used as-is in production.
Caveat emptor.**

You can point it at a different database by setting `DATABASE_URL` in the
environment before executing `app.rb`. See the relevant [Sequel
documentation](http://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html)
for more information. It (rather na&iuml;vely) migrates the database at
startup.

### Productionalizing

You can certainly use this as a starting point for a production application,
but you will at least want to:

- [ ] Use a persistent database
- [ ] Separate the class files (e.g. `author.rb`, `post.rb`) into separate
      files for the migrations, models, serializers, and Sinja controllers
- [ ] Create a Gemfile using the dependencies in the top-level
      [gemspec][/sinja.gemspec] as a starting point.
- [ ] Add authentication middleware and rewrite the `role` helper to enable
      the authorization scheme. You can use the existing roles as defined or
      rename them (e.g. use `:admin` instead of `:superuser`).
- [ ] Use a real application server such as [Puma](http://puma.io) or
      [Passenger](https://www.phusionpassenger.com) instead of Sinatra's
      default
- [ ] Configure Sequel's connection pool (i.e. `:max_connections`) to match the
      application server's thread pool (if any)
- [ ] Add caching directives (i.e. `cache_control`, `expires`, `last_modified`,
      and `etag`) as appropriate

And probably a whole lot more!
