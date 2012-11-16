# Dist

Generate packages to distribute Rails applications

## Installation

    $ gem install dist

## Usage

In your Rails root, run:

    $ dist

If it's the first time you run it, it will prompt you to run:

    $ dist init

This will create a `config/dist.rb` file that contains some information about how to create the package.

A typical `config/dist.rb` file looks like this:

    set :application, 'myrailsapp'
    set :version, '1.0'
    set :maintainer, 'John Doe <john@doe.com>'
    set :description, 'My awesome Rails app'
    set :summary, 'Demonstrates the usage of dist'

    use :mail

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
