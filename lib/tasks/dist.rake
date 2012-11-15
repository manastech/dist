namespace :dist do

  task :deb => [:assets, :output, :services] do
    puts "DONE!"
  end

  task :assets do
    Rake::Task["assets:clean"].invoke
    Rake::Task["assets:precompile"].invoke
  end

  task :output do
    rmtree 'debian'

    dirs = %W[
      debian/DEBIAN
      debian/etc/init
      debian/usr/share/#{app_name}
      debian/var/log/#{app_name}
      debian/var/lib/#{app_name}/bundle
      debian/var/lib/#{app_name}/gems
      debian/var/lib/#{app_name}/tmp
    ]

    dirs.each { |dir| mkdir_p dir }

    files = %w[app config config.ru db Gemfile Gemfile.lock lib plugins public Rakefile script vendor]
    files.each { |file| cp_r file, "debian/usr/share/#{app_name}" }

    ln_s "/var/lib/#{app_name}/bundle", "debian/usr/share/#{app_name}/vendor/bundle"
    ln_s "/var/lib/#{app_name}/gems", "debian/usr/share/#{app_name}/.gems"
    ln_s "/var/lib/#{app_name}/tmp", "debian/usr/share/#{app_name}/tmp"
    ln_s "/var/log/#{app_name}", "debian/usr/share/#{app_name}/log"

    # env = { 'GEM_HOME' => "#{Rails.root}/debian/usr/share/#{app_name}/.gems", 'GEM_PATH' => '', 'RUBYOPT' => '' }
    # system env, 'gem install bundler'
    # system env, 'gem install rake -v=0.9.2.2'
    # system env, 'gem install passenger'
  end

  task :services do
    procfile = YAML.load_file 'Procfile'
    rm_f 'debian/etc/init/*'

    require 'erb'
    main_template = ERB.new template('main')
    File.open("debian/etc/init/#{app_name}.conf", 'w') { |f| f.write main_template.result(binding) }

    service_template = ERB.new template('service')
    procfile.each do |service_name, service_command|
      next if service_name == 'web'
      File.open("debian/etc/init/#{app_name}-#{service_name}.conf", 'w') { |f| f.write service_template.result(binding) }
    end
  end

  def app_name
    @app_name ||= Rails.application.class.parent_name.downcase
  end

  def template(file)
    File.read(File.expand_path("../../templates/upstart/#{file}.erb", __FILE__))
  end

end