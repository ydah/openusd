# frozen_string_literal: true

require "bundler/gem_tasks"
require "fileutils"
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

namespace :golden do
  desc "Regenerate deterministic USDA golden files"
  task :update do
    require_relative "lib/openusd"

    source_root = File.expand_path("spec/fixtures", __dir__)
    destination = File.join(source_root, "golden")
    FileUtils.mkdir_p(destination)
    Dir[File.join(source_root, "{,upstream/}*.usda")].each do |source|
      name = source.delete_prefix("#{source_root}/").tr("/", "__")
      File.binwrite(File.join(destination, name), OpenUSD::Layer.open(source).to_usda)
    end
  end
end

module CompatibilityTask
  extend Rake::DSL

  module_function

  def write_assets(directory)
    usda_path = File.join(directory, "scene.usda")
    usdz_path = File.join(directory, "scene.usdz")
    stage = OpenUSD::Stage.create(usda_path)
    stage.define_prim("/World", "Xform")
    mesh = OpenUSD::Schema::Mesh.define(stage, "/World/Mesh")
    mesh.points = [[0, 0, 0], [1, 0, 0], [0, 1, 0]]
    mesh.face_vertex_counts = [3]
    mesh.face_vertex_indices = [0, 1, 2]
    mesh.extent = [[0, 0, 0], [1, 1, 0]]
    stage.root_layer.metadata.merge!(
      "defaultPrim" => "World", "metersPerUnit" => 1.0, "upAxis" => "Y"
    )
    stage.save
    stage.export(usdz_path)
    [usda_path, usdz_path]
  end

  def validate(assets)
    python = ENV.fetch("USD_CORE_PYTHON", nil)
    return validate_with_python(python, assets) if python

    assets.each { |path| sh ENV.fetch("USDCHECKER", "usdchecker"), path }
    usdcat = ENV.fetch("USDCAT", "usdcat")
    golden_paths.each { |path| sh usdcat, path, out: File::NULL }
  end

  def validate_with_python(python, assets)
    validator = File.expand_path("spec/support/usd_core_check.py", __dir__)
    sh python, validator, "validate", *assets
    sh python, validator, "parse", *golden_paths
  end

  def golden_paths
    Dir[File.expand_path("spec/fixtures/golden/*.usda", __dir__)]
  end
end

desc "Validate generated USDA and USDZ with the official usdchecker"
task :compatibility do
  require_relative "lib/openusd"

  Dir.mktmpdir("openusd-compatibility") do |directory|
    CompatibilityTask.validate(CompatibilityTask.write_assets(directory))
  end
end

task default: %i[spec lint]
