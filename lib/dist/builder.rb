require 'erb'

class Dist::Builder
  include FileUtils

  def initialize
    @templates = {}
  end

  def build
    # compile_assets
    build_output
    export_services
    export_control
  end

  private

  def compile_assets
    Rake::Task["assets:clean"].invoke
    Rake::Task["assets:precompile"].invoke
  end

  def build_output
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
  end

  def export_services
    procfile = YAML.load_file 'Procfile'
    rm_f 'debian/etc/init/*'

    write_template 'upstart/main', "debian/etc/init/#{app_name}.conf"

    procfile.each do |service_name, service_command|
      next if service_name == 'web'
      write_template 'upstart/service', "debian/etc/init/#{app_name}-#{service_name}.conf", binding
    end
  end

  def export_control
    write_template 'debian/control', 'debian/DEBIAN/control'
  end

  def app_name
    @app_name ||= Rails.application.class.parent_name.downcase
  end

  def config
    @config ||=
      Dist::Configuration.new.tap do |config|
        config.instance_eval File.read("#{Rails.root}/config/dist.rb")
      end
  end

  def packages
    @packages ||= compute_packages
  end

  def compute_packages
    packages = %w(ruby1.9.1 ruby1.9.1-dev build-essential libcurl4-openssl-dev libssl-dev)

    dependencies_yml = YAML.load_file File.expand_path('../../dependencies.yml', __FILE__)
    config.dependencies.each do |dependency|
      dependency_packages = dependencies_yml[dependency.to_s]
      if dependency_packages
        packages.concat dependency_packages
      else
        raise "Could not find packages for dependency: #{dependency}"
      end
    end
    packages
  end

  def write_template(source, target, binding_object = binding)
    template = @templates[source] ||= ERB.new(template source)
    File.open(target, 'w') { |f| f.write template.result(binding_object) }
  end

  def template(file)
    File.read(File.expand_path("../../templates/#{file}.erb", __FILE__))
  end
end