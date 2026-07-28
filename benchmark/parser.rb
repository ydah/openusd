# frozen_string_literal: true

require "openusd"

def resident_megabytes
  if File.file?("/proc/self/status")
    kilobytes = File.read("/proc/self/status")[/^VmRSS:\s+(\d+)/, 1]
    return kilobytes.to_i / 1024.0 if kilobytes
  end

  output = IO.popen(["ps", "-o", "rss=", "-p", Process.pid.to_s], &:read)
  Integer(output, 10) / 1024.0
rescue Errno::ENOENT, ArgumentError
  nil
end

def measure(label)
  GC.start
  memory_before = resident_megabytes
  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  result = yield
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
  memory_after = resident_megabytes
  memory = memory_before && memory_after ? format(", RSS +%.1f MiB", memory_after - memory_before) : ""
  puts "#{label} in #{format("%.3f", elapsed)} seconds#{memory}"
  [result, elapsed]
end

def run_prim_benchmark
  prim_count = Integer(ENV.fetch("PRIMS", "100000"))
  body = String.new(capacity: prim_count * 22)
  prim_count.times { |index| body << "def Xform \"P#{index}\" {}\n" }
  source = "#usda 1.0\n#{body}"

  layer, elapsed = measure("Parsed #{prim_count} prims") { OpenUSD::Format::Usda::Parser.parse(source) }
  raise "prim benchmark parsed the wrong count" unless layer.root_prims.length == prim_count

  budget = Float(ENV.fetch("PRIM_BUDGET", "5"))
  raise "prim benchmark exceeded #{budget} seconds" if elapsed > budget
end

def run_mesh_benchmark
  vertex_count = Integer(ENV.fetch("VERTICES", "1000000"))
  points = "(0, 0, 0)," * vertex_count
  source = "#usda 1.0\ndef Mesh \"Mesh\" { point3f[] points = [#{points}] }"
  layer, = measure("Parsed #{vertex_count} Mesh vertices") { OpenUSD::Format::Usda::Parser.parse(source) }
  parsed_points = layer.prim_at("/Mesh").property_named("points").default
  raise "mesh benchmark parsed the wrong vertex count" unless parsed_points.length == vertex_count
end

run_prim_benchmark
GC.start
run_mesh_benchmark
