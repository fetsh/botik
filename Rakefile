# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

# The gem is published on GitHub only for now: `rake release` tags and pushes
# to git but does not push to rubygems.org.
Rake::Task["release:rubygem_push"].clear
task "release:rubygem_push" do
  puts "Skipping rubygems.org push (GitHub-only releases)."
end

task default: %i[spec rubocop]
