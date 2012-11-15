namespace :dist do

  task :assets => :environment do
    Rake::Task["assets:clean"].invoke
    Rake::Task["assets:precompile"].invoke
  end

  task :output => :environment do
    rmtree 'debian'

    app_name = Rails.application.class.parent_name.downcase

    dirs = %W[
      debian/DEBIAN
      debian/usr/share/#{app_name}
      debian/var/log/#{app_name}
      debian/var/lib/#{app_name}/bundle
      debian/var/lib/#{app_name}/tmp
    ]

    dirs.each { |dir| mkdir_p dir }

    files = %w[app config config.ru db Gemfile Gemfile.lock lib plugins public Rakefile script vendor]
    files.each { |file| cp_r file, "debian/usr/share/#{app_name}" }

    ln_s "/var/lib/#{app_name}/bundle", "debian/usr/share/#{app_name}/vendor/bundle"
    ln_s "/var/lib/#{app_name}/tmp", "debian/usr/share/#{app_name}/tmp"
    ln_s "/var/log/#{app_name}", "debian/usr/share/#{app_name}/log"

    env = { 'GEM_HOME' => "#{Rails.root}/debian/usr/share/#{app_name}/.gems", 'GEM_PATH' => '', 'RUBYOPT' => '' }
    system env, 'gem install bundler'
    system env, 'gem install rake -v=0.9.2.2'
    system env, 'gem install passenger'
  end

end