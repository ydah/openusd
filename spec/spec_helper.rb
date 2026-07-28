# frozen_string_literal: true

require "simplecov"
require "tmpdir"

SimpleCov.start do
  enable_coverage :branch
  add_filter "/spec/"
  minimum_coverage line: 90
end

require "openusd"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
