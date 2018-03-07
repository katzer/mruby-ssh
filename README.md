# Simple SSH client for mruby <br> [![Build Status](https://travis-ci.org/katzer/mruby-ssh.svg?branch=master)](https://travis-ci.org/katzer/mruby-ssh) [![Build status](https://ci.appveyor.com/api/projects/status/bkd5aem5ap1n22cs/branch/master?svg=true)](https://ci.appveyor.com/project/katzer/mruby-ssh/branch/master)

Inspired by [Net::SSH][net_ssh], empowers [mruby][mruby], a work in progress!

## Installation

Add the line below to your `build_config.rb`:

```ruby
MRuby::Build.new do |conf|
  # ... (snip) ...
  conf.gem 'mruby-ssh'
end
```

Or add this line to your aplication's `mrbgem.rake`:

```ruby
MRuby::Gem::Specification.new('your-mrbgem') do |spec|
  # ... (snip) ...
  spec.add_dependency 'mruby-ssh'
end
```

## Development

Clone the repo:
    
    $ git clone https://github.com/katzer/mruby-ssh.git && cd mruby-ssh/

Compile the source:

    $ rake compile

Run the tests:

    $ rake test

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/katzer/mruby-ssh.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Authors

- Sebastián Katzer, Fa. appPlant GmbH

## License

The mgem is available as open source under the terms of the [MIT License][license].

Made with :yum: from Leipzig

© 2017 [appPlant GmbH][appplant]

[mruby]: https://github.com/mruby/mruby
[net_ssh]: https://github.com/net-ssh/net-ssh
[license]: http://opensource.org/licenses/MIT
[appplant]: www.appplant.de