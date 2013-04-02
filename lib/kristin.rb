require "kristin/version"
require 'open-uri'
require "net/http"

module Kristin
  class Converter
    def initialize(source, target, options = {})
      @options = options
      @source = source
      @target = target
    end

    def convert
      raise IOError, "Can't find pdf2htmlex executable in PATH" if not command_available?
      src = determine_source(@source)
      opts = process_options
      cmd = "#{pdf2htmlex_command} #{opts} #{src} #{@target}"
      pid = Process.spawn(cmd, [:out, :err] => "/dev/null")
      Process.waitpid(pid)
      
      ## TODO: Grab error message from pdf2htmlex and raise a better error
      raise IOError, "Could not convert #{src}" if $?.exitstatus != 0
    end

    private

    def process_options
      opts = []
      opts.push("--process-outline 0") if @options[:process_outline] == false

      opts.join(" ")
    end

    def command_available?
      pdf2htmlex_command
    end

    def pdf2htmlex_command
      cmd = nil
      cmd = "pdf2htmlex" if which("pdf2htmlex")
      cmd = "pdf2htmlEX" if which("pdf2htmlEX")
    end

    def which(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
        ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
          exts.each do |ext|
            exe = File.join(path, "#{cmd}#{ext}")
            return exe if File.executable? exe
          end
        end
      return nil
    end

    def random_source_name
      rand(16**16).to_s(16)
    end

    def download_file(source)
      tmp_file = "/tmp/#{random_source_name}.pdf"
      File.open(tmp_file, "wb") do |saved_file|
        open(source, 'rb') do |read_file|
          saved_file.write(read_file.read)
        end
      end

      tmp_file
    end

    def determine_source(source)
      is_file = File.exists?(source) && !File.directory?(source)
      is_http = (URI(source).scheme == "http" || URI(source).scheme == "https") && Net::HTTP.get_response(URI(source)).is_a?(Net::HTTPSuccess)
      raise IOError, "Source (#{source}) is neither a file nor an URL." unless is_file || is_http
    
      is_file ? source : download_file(source)
    end
  end

  def self.convert(source, target, options = {})
    Converter.new(source, target, options).convert
  end
end