require 'bundler/setup'
require 'erb'
require 'fileutils'
require 'yaml'
require 'set'

class Dist::Builder
  include Dist::Error
  include FileUtils::Verbose

  OutputDir = "tmp/dist"

  attr_reader :config
  attr_reader :packages

  def initialize(options = {})
    @templates = {}
    @options = options
  end

  def build
    load_configuration
    compute_packages
    compile_assets if !@options[:skip_assets] && assets_enabled
    build_output
    generate_logrotate
    export_services
    export_control
    build_package
  end

  def init
   @app_name = File.basename(FileUtils.pwd)

   write_template 'config', 'config/dist.rb'
  end

  private

  def rails
    @rails ||= begin
      puts "Loading Rails..."
      require './config/boot'
      require './config/application'
      Rails
    end
  end

  def assets_enabled
    @assets_enabled ||= rails.configuration.assets.enabled rescue false
  end

  def database_enabled
    @database_enabled ||= begin
      rails
      defined? ActiveRecord
    end
  end

  def compile_assets
    system 'bundle exec rake assets:clean assets:precompile'
  end

  def build_output
    rmtree OutputDir

    dirs = %W[
      DEBIAN
      etc/#{app_name}
      etc/init
      etc/logrotate.d
      #{app_root}
      #{app_root}/vendor
      var/log/#{app_name}
      var/lib/#{app_name}/bundle
      var/lib/#{app_name}/gems
      var/lib/#{app_name}/tmp
    ]

    dirs.each { |dir| mkdir_p "#{OutputDir}/#{dir}" }

    files = Dir['*'] - %w(log tmp test spec)
    files.each { |file| cp_r file, "#{OutputDir}/#{app_root}" }

    ln_s "/var/lib/#{app_name}/bundle", "#{OutputDir}/#{app_root}/vendor/bundle"
    ln_s "/var/lib/#{app_name}/gems", "#{OutputDir}/#{app_root}/.gems"
    ln_s "/var/lib/#{app_name}/tmp", "#{OutputDir}/#{app_root}/tmp"
    ln_s "/var/log/#{app_name}", "#{OutputDir}/#{app_root}/log"
    ln_sf "/etc/#{app_name}/database.yml", "#{OutputDir}/#{app_root}/config/database.yml"
  end

  def export_services
    if File.exists? 'Procfile'
      procfile = YAML.load_file 'Procfile'
      rm_f "#{OutputDir}/etc/init/*"

      procfile.each do |service_name, service_command|
        next if service_name == 'web'
        if service_command =~ /\Abundle\s+exec\s+(.*)/
          service_command = $1
        end
        write_template 'upstart/service', "#{OutputDir}/etc/init/#{app_name}-#{service_name}.conf", binding
      end
    end

    write_template 'upstart/main', "#{OutputDir}/etc/init/#{app_name}.conf"
    write_template 'upstart/passenger', "#{OutputDir}/etc/init/#{app_name}-passenger.conf"
  end

  def generate_logrotate
    write_template 'logrotate', "#{OutputDir}/etc/logrotate.d/#{app_name}"
  end

  def export_control
    %w(control postinst prerm postrm config templates).each do |control_file|
      write_template "debian/#{control_file}", "#{OutputDir}/DEBIAN/#{control_file}"
    end

    %w(postinst prerm postrm config).each do |control_file|
      chmod 0755, "#{OutputDir}/DEBIAN/#{control_file}"
    end
  end

  def build_package
    system "fakeroot dpkg-deb --build #{OutputDir} #{app_name}_#{config.version}.deb"
  end

  def app_name
    @app_name ||= config.application
  end

  def app_root
    @app_root = "/usr/share/#{app_name}"
  end

  def load_configuration
    @config = Dist::Configuration.new
  end

  def compute_packages
    @packages = Dist::PackageComputer.new(@config, @options).packages
  end

  def write_template(source, target, binding_object = binding)
    template = @templates[source] ||= ERB.new(template(source), nil, '<>')
    puts "write #{target} from template #{source}"
    File.open(target, 'w') { |f| f.write template.result(binding_object) }
  end

  def template(file)
    File.read(File.expand_path("../../templates/#{file}.erb", __FILE__))
  end

  def system(*args)
    puts *args
    Kernel::system *args
  end
end
