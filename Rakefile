# require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require 'bundler/gem_helper'

module Bundler
  class GemHelper
    def rubygem_push(_path)
      Bundler.ui.confirm "Pushed #{name} #{version} to NOWHERE"
    end
  end
end

namespace :gem do
  Bundler::GemHelper.install_tasks
end

task :default => :spec
