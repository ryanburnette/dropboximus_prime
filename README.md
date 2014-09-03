Dropboximus Prime
=================

**Dropboximus Prime** is a Ruby library which uses Dropbox as a remote management
location and processes common web content including Markdown and YAML.

Standard use cases include Sinatra and Ruby sites where content is stored in
a Dropbox folder shared among publishers. Objects will be filled with site content
in the Model using the `get` method. Markdown files become HTML. YAML files
become a Hash or Array. Images become an object with useful methods for creating
associated image tags.

The library supports globbing of the local cache.

The `refresh` and `prune` methods can be scheduled to keep sites up-to-date
with changes.

This library is a work in progress and is intended for simple use cases.

Supported Formats
-----------------

+ Markdown
+ YAML
+ Images

Installation
------------

Install or bundle the gem and include in your app.

```bash
gem install dropboximus_prime
```

```ruby
# app.rb
include 'dropboximus_prime'
```

Make sure a `dropboximus_prime.yml` file exists in your `config` directory.

```yaml
dropbox:
  access_token: abc123
  path: /apps/mysite.com
cache:
  path: dropboximus_prime/cache
  http_prefix: /cache/
tmp_cache:
  path: dropboximus_prime/tmp/cache
rev_cache:
  path: dropboximus_prime/rev/cache
```

You can get an access token by registering a Dropbox app with your developer account.

Make sure the folders you've specified in your config exist in your App's root.

```bash
mkdir -p dropboximus_prime/cache
mkdir -p dropboximus_prime/tmp/cache
mkdir -p dropboximus_prime/rev/cache
```

It's assume that you'll configure your web server to access the cache path. It's
also suggested that you deny requests to files that start with an underscore.

Usage
-----

It's assume that you'll use from your models, but you could use it right from
your views as well.

```ruby
# model.rb
d = DropboximusPrime.new

# Markdown becomes HTML
content = d.get 'pages/home/_content.md'

# YAML becomes Array/Hash
list = d.get 'pages/home/_list.yml'

# Images have helpful methods for creating slideshows
images = d.get 'pages/home/images/*'
```

```html
<!-- view.erb -->

<div class="content"><%= content %></div>

<ul>
  <% list.each do |item| %>
  <li><%= item %></li>
  <% end %>
</ul>

<% images.each do |image| %>
<img src="<%= image.src %>" alt="<%= image.alt %>" data-thumbnail="<%= image.thumbnail_l_src %>">
<% end %>
```

Issues
------

Feel free to report issues and make pull requests.

Version History
---------------

+ 0.2.4
  + Get now returns certain format as raw, others with the public URL
  + Anything else returns nil

+ 0.2.3
  + Images no longer return bad path info

+ 0.2.2
  + If not a known format, return file contents when using get method

+ 0.2.1
  + Make util methods private

+ 0.2.0
  + New usage pattern
  + Compare remote instead of cache timeouts
  + Globbing
  + Other improvements

+ 0.1.3

+ 0.1.2

+ 0.1.1

+ 0.1.0
  + Initial version

License
-------

Apache2
