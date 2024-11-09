class LibBuilder
  def initialize(context, name, version)
    @context = context
    @name    = name
    @spec = Gem::Specification.new do |s|
      s.name        = name
      s.version     = version
      s.summary     = "This is just a fake gem for testing"
      s.description = "This is a completely fake gem, for testing purposes."
      s.author      = "no one"
      s.email       = "foo@bar.baz"
      s.homepage    = "http://example.com"
      s.license     = "MIT"
      s.required_ruby_version = ">= 3.0"
    end
    @files = {}
  end

  def method_missing(*args, &blk)
    @spec.send(*args, &blk)
  end

  def write(file, source = "")
    @files[file] = source
  end

  def executables=(val)
    @spec.executables = Array(val)
    @spec.executables.each do |file|
      executable = "#{@spec.bindir}/#{file}"
      shebang = "#!/usr/bin/env ruby\n"
      @spec.files << executable
      write executable, "#{shebang}require_relative '../lib/#{@name}' ; puts #{Builders.constantize(@name)}"
    end
  end

  def add_c_extension
    extensions << "ext/extconf.rb"
    write "ext/extconf.rb", <<-RUBY
          require "mkmf"

          extension_name = "#{name}_c"
          if extra_lib_dir = with_config("ext-lib")
            # add extra libpath if --with-ext-lib is
            # passed in as a build_arg
            dir_config extension_name, nil, extra_lib_dir
          else
            dir_config extension_name
          end
          create_makefile extension_name
    RUBY
    write "ext/#{name}.c", <<-C
          #include "ruby.h"

          void Init_#{name}_c(void) {
            rb_define_module("#{Builders.constantize(name)}_IN_C");
          }
    C
  end

  def _build(options)
    path = options[:path] || _default_path

    if options[:rubygems_version]
      @spec.rubygems_version = options[:rubygems_version]

      def @spec.validate(*); end
    end

    unless options[:no_default]
      gem_source = options[:source] || "path@#{path}"
      @files = _default_files.
        merge("lib/#{entrypoint}/source.rb" => "#{Builders.constantize(name)}_SOURCE = #{gem_source.to_s.dump}").
        merge(@files)
    end

    @spec.authors = ["no one"]
    @spec.files += @files.keys

    case options[:gemspec]
    when false
      # do nothing
    when :yaml
      @spec.files << "#{name}.gemspec"
      @files["#{name}.gemspec"] = @spec.to_yaml
    else
      @spec.files << "#{name}.gemspec"
      @files["#{name}.gemspec"] = @spec.to_ruby
    end

    @files.each do |file, source|
      full_path = Pathname.new(path).join(file)
      FileUtils.mkdir_p(full_path.dirname)
      File.open(full_path, "w") {|f| f.puts source }
      FileUtils.chmod("+x", full_path) if @spec.executables.map {|exe| "#{@spec.bindir}/#{exe}" }.include?(file)
    end
    path
  end

  def _default_files
    @_default_files ||= { "lib/#{entrypoint}.rb" => "#{Builders.constantize(name)} = '#{version}#{platform_string}'" }
  end

  def entrypoint
    name.tr("-", "/")
  end

  def _default_path
    @context.tmp("libs", @spec.full_name)
  end

  def platform_string
    " #{@spec.platform}" unless @spec.platform == Gem::Platform::RUBY
  end
end


class GemBuilder < LibBuilder
  def _build(opts)
    lib_path = opts[:lib_path] || @context.tmp(".tmp/#{@spec.full_name}")
    lib_path = super(opts.merge(path: lib_path, no_default: opts[:no_default]))
    destination = opts[:path] || _default_path
    FileUtils.mkdir_p(lib_path.join(destination))

    if opts[:gemspec] == :yaml || opts[:gemspec] == false
      Dir.chdir(lib_path) do
        Bundler.rubygems.build(@spec, opts[:skip_validation])
      end
    elsif opts[:skip_validation]
      @context.gem_command "build --force #{@spec.name}", dir: lib_path
    else
      @context.gem_command "build #{@spec.name}", dir: lib_path
    end

    gem_path = File.expand_path("#{@spec.full_name}.gem", lib_path)
    if opts[:to_system]
      @context.system_gems gem_path, default: opts[:default]
    elsif opts[:to_bundle]
      @context.system_gems gem_path, path: @context.default_bundle_path
    else
      FileUtils.mv(gem_path, destination)
    end
  end

  def _default_path
    @context.gem_repo1("gems")
  end
end


