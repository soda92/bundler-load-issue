require_relative "file"
require_relative "helper"

def bundle(cmd, options = {}, &block)
  bundle_bin = options.delete(:bundle_bin)
  bundle_bin ||= installed_bindir.join("bundle")

  env = options.delete(:env) || {}
  preserve_ruby_flags = options.delete(:preserve_ruby_flags)

  requires = options.delete(:requires) || []

  dir = options.delete(:dir) || bundled_app
  custom_load_path = options.delete(:load_path)

  load_path = []
  load_path << spec_dir
  load_path << custom_load_path if custom_load_path

  build_ruby_options = { load_path: load_path, requires: requires, env: env }
  build_ruby_options.merge!(artifice: options.delete(:artifice)) if options.key?(:artifice)

  match_source(cmd)

  env, ruby_cmd = build_ruby_cmd(build_ruby_options)

  raise_on_error = options.delete(:raise_on_error)

  args = options.map do |k, v|
    case v
    when true
      " --#{k}"
    when false
      " --no-#{k}"
    else
      " --#{k} #{v}"
    end
  end.join

  cmd = "#{ruby_cmd} #{bundle_bin} #{cmd}#{args}"
  env["BUNDLER_SPEC_ORIGINAL_CMD"] = "#{ruby_cmd} #{bundle_bin}" if preserve_ruby_flags
  sys_exec(cmd, { env: env, dir: dir, raise_on_error: raise_on_error }, &block)
end


