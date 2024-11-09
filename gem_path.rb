require "pathname"

def default_bundle_path(*path)
    local_gem_path(*path)
end

def bundled_app(*path)
  root = tmp("bundled_app")
  FileUtils.mkdir_p(root)
  root.join(*path)
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

def test_env_version
  1
end




def scope
  test_number = ENV["TEST_ENV_NUMBER"]
  return "1" if test_number.nil?

  test_number.empty? ? "1" : test_number
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

def gem_repo1(*args)
      tmp("gems/remote1", *args)
    end

