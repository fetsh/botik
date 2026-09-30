# frozen_string_literal: true

require_relative "lib/botik/version"

Gem::Specification.new do |spec|
  spec.name          = "botik"
  spec.version       = Botik::VERSION
  spec.authors       = ["Ilia Zemskov"]
  spec.email         = ["il.zoff@gmail.com"]

  spec.summary       = "Rails-style framework for Telegram bots: routes, controllers, views."
  spec.description   = <<~DESC
    Botik lets you build Telegram bots the way you build Rails apps: a routing DSL
    maps updates to controller actions, controllers use before/after actions and
    rescue_from, and replies are rendered from ERB views. Several independent bots
    (each with its own token, routes, controllers and views) can live in one project.
  DESC
  spec.homepage      = "https://github.com/fetsh/botik"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/master/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*", "docs/**/*", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 7.1"
  spec.add_dependency "erubi", "~> 1.12"
end
