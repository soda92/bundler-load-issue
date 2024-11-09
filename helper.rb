def system_gems(*gems)
  gems = gems.flatten
  options = gems.last.is_a?(Hash) ? gems.pop : {}
  install_dir = options.fetch(:path, system_gem_path)
  default = options.fetch(:default, false)
  gems.each do |g|
    gem_name = g.to_s
    if gem_name.start_with?("bundler")
      version = gem_name.match(/\Abundler-(?<version>.*)\z/)[:version] if gem_name != "bundler"
      with_built_bundler(version) {|gem_path| install_gem(gem_path, install_dir, default) }
    elsif %r{\A(?:[a-zA-Z]:)?/.*\.gem\z}.match?(gem_name)
      install_gem(gem_name, install_dir, default)
    else
      gem_repo = options.fetch(:gem_repo, gem_repo1)
      install_gem("#{gem_repo}/gems/#{gem_name}.gem", install_dir, default)
    end
  end
end

def with_built_bundler(version = nil, &block)
  require_relative "builders"

  Builders::BundlerBuilder.new(self, "bundler", version)._build(&block)
end

def install_gem(path, install_dir, default = false)
  raise "OMG `#{path}` does not exist!" unless File.exist?(path)

  args = "--no-document --ignore-dependencies --verbose --local --install-dir #{install_dir}"
  args += " --default" if default

  gem_command "install #{args} '#{path}'"
end

def gem_command(command, options = {})
  env = options[:env] || {}
  env["RUBYOPT"] = opt_add(opt_add("-r#{spec_dir}/support/hax.rb", env["RUBYOPT"]), ENV["RUBYOPT"])
  options[:env] = env

  # Sometimes `gem install` commands hang at dns resolution, which has a
  # default timeout of 60 seconds. When that happens, the timeout for a
  # command is expired too. So give `gem install` commands a bit more time.
  options[:timeout] = 120

  output = sys_exec("#{Path.gem_bin} #{command}", options)
  stderr = last_command.stderr
  raise stderr if stderr.include?("WARNING") && !allowed_rubygems_warning?(stderr)
  output
end

def opt_add(option, options)
  [option.strip, options].compact.reject(&:empty?).join(" ")
end


