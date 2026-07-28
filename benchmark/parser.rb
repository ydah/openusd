# frozen_string_literal: true

require "openusd"

prim_count = Integer(ENV.fetch("PRIMS", "100000"))
body = String.new(capacity: prim_count * 22)
prim_count.times { |index| body << "def Xform \"P#{index}\" {}\n" }
source = "#usda 1.0\n#{body}"

started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
OpenUSD::Format::Usda::Parser.parse(source)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
puts "Parsed #{prim_count} prims in #{format("%.3f", elapsed)} seconds"
