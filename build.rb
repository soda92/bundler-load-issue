require_relative "builder"

def build_gem(name, *args, &blk)
  build_with(GemBuilder, name, args, &blk)
end

def build_with(builder, name, args, &blk)
  @_build_path ||= nil
  @_build_repo ||= nil
  options  = args.last.is_a?(Hash) ? args.pop : {}
  versions = args.last || "1.0"
  spec     = nil

  options[:path] ||= @_build_path
  options[:source] ||= @_build_repo

  Array(versions).each do |version|
    spec = builder.new(self, name, version)
    yield spec if block_given?
    spec._build(options)
  end

  spec
end


build_gem "myrack", %w[0.9.1 1.0.0] do |s|
  s.executables = "myrackup"
  s.post_install_message = "Myrack's post install message"
end

