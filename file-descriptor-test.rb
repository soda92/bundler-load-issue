if ARGV[0]
IO.for_fd(ARGV[0].to_i)
	else
	require 'tempfile'
	io = Tempfile.new("io-test-fd")
	args = %W[C:/Ruby33-x64/bin/ruby.exe -IE:/src/rubygems/bundler/tmp/1.1/gems/system/gems/bundler-2.6.0.dev/lib E:/src/rubygems/bundler/exe/bundle exec --keep-file-descriptors C:/Ruby33-x64/bin/ruby.exe E:/src/rubygems/bundler/tmp/1.1/tmpdir/io-test20241110-13540-5n6x2o #{io.to_i}]
	args << { io.to_i => io }
exec(*args)
	end
