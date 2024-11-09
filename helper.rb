require_relative "gem_path"
require_relative "command_execution"


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

def sys_exec(cmd, options = {}, &block)
  env = options[:env] || {}
  env["RUBYOPT"] = opt_add(opt_add("-r#{spec_dir}/support/switch_rubygems.rb", env["RUBYOPT"]), ENV["RUBYOPT"])
  options[:env] = env
  options[:dir] ||= bundled_app

  sh(cmd, options, &block)
end

def sh(cmd, options = {})
  dir = options[:dir]
  env = options[:env] || {}

  command_execution = CommandExecution.new(cmd.to_s, working_directory: dir, timeout: options[:timeout] || 60)

  require "open3"
  require "shellwords"
  Open3.popen3(env, *cmd.shellsplit, chdir: dir) do |stdin, stdout, stderr, wait_thr|
    yield stdin, stdout, wait_thr if block_given?
    stdin.close

    stdout_handler = ->(data) { command_execution.original_stdout << data }
    stderr_handler = ->(data) { command_execution.original_stderr << data }

    stdout_thread = read_stream(stdout, stdout_handler, timeout: command_execution.timeout)
    stderr_thread = read_stream(stderr, stderr_handler, timeout: command_execution.timeout)

    stdout_thread.join
    stderr_thread.join

    status = wait_thr.value
    command_execution.exitstatus = if status.exited?
                                     status.exitstatus
                                   elsif status.signaled?
                                     exit_status_for_signal(status.termsig)
                                   end
  rescue TimeoutExceeded
    command_execution.failure_reason = :timeout
    command_execution.exitstatus = exit_status_for_signal(Signal.list["INT"])
  end

  unless options[:raise_on_error] == false || command_execution.success?
    command_execution.raise_error!
  end

  command_executions << command_execution

  command_execution.stdout
end


