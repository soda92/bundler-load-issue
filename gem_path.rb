def default_bundle_path(*path)
  if Bundler.feature_flag.default_install_uses_path?
    local_gem_path(*path)
  else
    system_gem_path(*path)
  end
end

def local_gem_path(*path, base: bundled_app)
  scoped_gem_path(base.join(".bundle")).join(*path)
end

def scoped_gem_path(base)
  base.join(Gem.ruby_engine, RbConfig::CONFIG["ruby_version"])
end

def system_gem_path(*path)
  tmp("gems/system", *path)
end

def tmp(*path)
  tmp_root(scope).join(*path)
end

def tmp_root(scope)
  source_root.join("tmp", "#{test_env_version}.#{scope}")
end

def source_root
  @source_root ||= Pathname.new(ruby_core? ? "../../.." : "../..").expand_path(__dir__)
end

def ruby_core?
  File.exist?(File.expand_path("../../../lib/bundler/bundler.gemspec", __dir__))
end
