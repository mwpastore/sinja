## Demo App

This is the demo app for Sinja, provided both as an example of and for testing
Sinja. It uses [Sequel ORM](http://sequel.jeremyevans.net) with an in-memory
SQLite database and demonstrates the [Sequel extension](/extensions/sequel) for
Sinja. It works under both MRI/YARV 2.3+ and JRuby 9.1+. It is a very
simplistic blog-like application with [database
tables](http://sequel.jeremyevans.net/rdoc/files/doc/schema_modification_rdoc.html),
[models](http://sequel.jeremyevans.net/rdoc/files/README_rdoc.html#label-Sequel+Models),
[serializers](https://github.com/fotinakis/jsonapi-serializers), and
[controllers](/) for [authors](/demo-app/classes/author.rb),
[posts](/demo-app/classes/post.rb), [comments](/demo-app/classes/comment.rb),
and [tags](/demo-app/classes/tag.rb).

### Usage

Assuming you have a working, [Bundler](http://bundler.io)-enabled Ruby
environment, simply clone this repo, `cd` into the `demo-app` subdirectory, and
run the following commands:

```
$ bundle install
$ bundle exec ruby app.rb [-p <PORT>]
```

The web server will report the port it's listening on (most likely 4567), or
you can specify a port with the `-p` option. Alternatively, if you don't want
to set up a Ruby environment just for a quick demo, it's [available on Docker
Cloud](https://cloud.docker.com/app/mwpastore/repository/docker/mwpastore/sinja-demo-app):

```
$ docker run -it -p 4567:4567 --rm mwpastore/sinja-demo-app
```

It will respond to {json:api}-compliant requests (don't forget to set an
`Accept` header) to `/authors`, `/posts`, `/comments`, and `/tags`, although
not every endpoint is implemented. Log in by setting the `X-Email` header on
the request to the email address of a registered user; the email address for
the default admin user is all@yourbase.com. **This is clearly extremely
insecure and should not be used as-is in production. Caveat emptor.**

You can point it at a different database by setting `DATABASE_URL` in the
environment before executing `app.rb`. See the relevant [Sequel
documentation](http://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html)
for more information. It (rather na&iuml;vely) migrates the database and
creates the default admin user at startup.

### Productionalizing

You can certainly use this as a starting point for a production application,
but you will at least want to:

- [ ] Use a persistent database
- [ ] Remove or change the default admin user
- [ ] Separate the class files (e.g. `author.rb`, `post.rb`) into separate
      files for migrations, models, serializers, and Sinja controllers
- [ ] Create a Gemfile using the dependencies in the top-level
      [gemspec](/sinja.gemspec) as a starting point
- [ ] Add authentication and rewrite the `role` helper to enable the
      authorization scheme. You can use the existing roles as defined or rename
      them (e.g. use `:admin` instead of `:superuser`)
- [ ] Use a real application server such as [Puma](http://puma.io) or
      [Passenger](https://www.phusionpassenger.com) instead of Ruby's
      stdlib (WEBrick)
- [ ] Configure Sequel's connection pool (i.e. `:max_connections`) to match the
      application server's thread pool (if any) size, e.g.
      `Puma.cli_config.options[:max_threads]`
- [ ] Add caching directives (i.e. `cache_control`, `expires`, `last_modified`,
      and `etag`) as appropriate

And probably a whole lot more!
