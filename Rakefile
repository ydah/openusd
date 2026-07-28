# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "tmpdir"
require "yard"
require "yard/rake/yardoc_task"

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new(:lint)

YARD::Rake::YardocTask.new(:doc) do |task|
  task.files = ["lib/**/*.rb", "exe/openusd"]
end

desc "Run the USDA parser benchmark"
task :bench do
  ruby "-Ilib", "benchmark/parser.rb"
end

desc "Validate generated USDA and USDZ with the official usdchecker"
task :compatibility do
  require_relative "lib/openusd"

  Dir.mktmpdir("openusd-compatibility") do |directory|
    usda_path = File.join(directory, "scene.usda")
    usdz_path = File.join(directory, "scene.usdz")
    stage = OpenUSD::Stage.create(usda_path)
    stage.define_prim("/World", "Xform")
    stage.root_layer.metadata.merge!(
      "defaultPrim" => "World",
      "metersPerUnit" => 1.0,
      "upAxis" => "Y"
    )
    stage.save
    stage.export(usdz_path)
    [usda_path, usdz_path].each { |path| sh ENV.fetch("USDCHECKER", "usdchecker"), path }
  end
end

task default: %i[spec lint]
