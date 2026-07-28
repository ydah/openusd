# frozen_string_literal: true

require "optparse"

module OpenUSD
  # Command-line interface used by the `openusd` executable.
  class CLI
    # Supported subcommand names.
    COMMANDS = %w[cat tree zip].freeze

    def initialize(stdout: $stdout, stderr: $stderr)
      @stdout = stdout
      @stderr = stderr
    end

    # Run a command and return a process exit status.
    # @param arguments [Array<String>]
    # @return [Integer]
    def run(arguments)
      argv = arguments.dup
      command = argv.shift
      return print_help(0) if command.nil? || %w[-h --help help].include?(command)
      return print_version if %w[-v --version version].include?(command)
      return unknown_command(command) unless COMMANDS.include?(command)

      send("run_#{command}", argv)
      0
    rescue OptionParser::ParseError, ArgumentError, OpenUSD::Error, SystemCallError => e
      @stderr.puts("openusd: #{e.message}")
      1
    end

    private

    def run_cat(argv)
      output = nil
      show_help = false
      parser = OptionParser.new do |options|
        options.banner = "Usage: openusd cat [options] FILE"
        options.on("-o", "--output PATH", "Write formatted USDA to PATH") { |path| output = path }
        options.on("-h", "--help", "Show this help") { show_help = true }
      end
      parser.parse!(argv)
      return @stdout.puts(parser) if show_help

      input = required_argument(argv, parser)
      ensure_no_arguments!(argv, parser)
      text = Layer.open(input).to_usda
      output ? File.binwrite(output, text) : @stdout.write(text)
    end

    def run_tree(argv)
      show_help = false
      parser = OptionParser.new
      parser.banner = "Usage: openusd tree FILE"
      parser.on("-h", "--help", "Show this help") { show_help = true }
      parser.parse!(argv)
      return @stdout.puts(parser) if show_help

      input = required_argument(argv, parser)
      ensure_no_arguments!(argv, parser)
      Stage.open(input).traverse do |prim|
        depth = prim.path.to_s.count("/") - 1
        type = prim.type_name ? " <#{prim.type_name}>" : ""
        @stdout.puts("#{"  " * depth}#{prim.name}#{type}")
      end
    end

    def run_zip(argv)
      show_help = false
      parser = OptionParser.new
      parser.banner = "Usage: openusd zip OUTPUT.usdz ROOT.usd[a|c] [ASSET ...]"
      parser.on("-h", "--help", "Show this help") { show_help = true }
      parser.parse!(argv)
      return @stdout.puts(parser) if show_help

      output = required_argument(argv, parser)
      root = required_argument(argv, parser)
      Format::Usdz::Writer.pack(output, root: root, assets: argv)
      @stdout.puts(output)
    end

    def required_argument(argv, parser)
      argv.shift || raise(OptionParser::MissingArgument, parser.banner)
    end

    def ensure_no_arguments!(argv, parser)
      raise OptionParser::InvalidArgument, "#{parser.banner}: #{argv.join(" ")}" unless argv.empty?
    end

    def print_help(status)
      @stdout.puts <<~HELP
        Usage: openusd COMMAND [options]

        Commands:
          cat FILE                    Parse and format a USDA or USDZ root layer
          tree FILE                   Print the composed prim hierarchy
          zip OUTPUT ROOT [ASSET...]  Create an aligned, uncompressed USDZ package

        Run `openusd COMMAND --help` for command-specific options.
      HELP
      status
    end

    def print_version
      @stdout.puts("openusd #{VERSION}")
      0
    end

    def unknown_command(command)
      @stderr.puts("openusd: unknown command #{command.inspect}")
      print_help(1)
    end
  end
end
