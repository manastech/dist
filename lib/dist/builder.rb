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
    @yaml_loader = Dist::YamlLoader.new options
    @options = options
  end

  def build
    load_configuration
    compute_packages
    compile_assets unless @options[:skip_assets]
    build_output
    export_services
    export_control
    build_package
  end

  def init
   @app_name = File.basename(FileUtils.pwd)

   write_template 'config', 'config/dist.rb'
  end

  private

  def compile_assets
    exec 'bundle exec rake assets:clean assets:precompile'
  end

  def build_output
    rmtree OutputDir

    dirs = %W[
      DEBIAN
      etc/#{app_name}
      etc/init
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

  def export_control
    %w(control postinst prerm postrm config templates).each do |control_file|
      write_template "debian/#{control_file}", "#{OutputDir}/DEBIAN/#{control_file}"
    end

    %w(postinst prerm postrm config).each do |control_file|
      chmod 0755, "#{OutputDir}/DEBIAN/#{control_file}"
    end
  end

  def build_package
    exec "fakeroot dpkg-deb --build #{OutputDir} #{app_name}_#{config.version}.deb"
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
    puts "computing packages:"
    @gems_yml = @yaml_loader.load 'gems'
    @dependencies_yml = @yaml_loader.load 'dependencies'
    @dependencies = Set.new
    @packages = Set.new
    @indent = 1
    add_default_dependencies
    add_dependencies_from_use
    add_dependencies_from_bundle
    @packages = @packages.to_a
  end

  def add_default_dependencies
    add_packages_from_dependency('default')
  end

  def add_dependencies_from_use
    config.dependencies.each do |dependency|
      if @dependencies.add?(dependency)
        add_packages_from_dependency(dependency)
      end
    end
  end

  def add_dependencies_from_bundle
    Bundler.load.specs.each do |spec|
      gem_depenencies = @gems_yml[spec.name]
      if gem_depenencies
        printed_gem = false
        gem_depenencies.each do |dependency|
          if @dependencies.add?(dependency)
            unless printed_gem
              puts_with_indent "gem :#{spec.name}"
              printed_gem = true
            end
            with_indent do
              add_packages_from_dependency(dependency)
            end
          end
        end
      end
    end
  end

  def add_packages_from_dependency(dependency)
    puts_with_indent "use :#{dependency}"
    with_indent do
      dependency_packages = @dependencies_yml[dependency.to_s]
      if dependency_packages
        dependency_packages.each do |package|
          puts_with_indent "package :#{package}"
          @packages << package
        end
      else
        error_at "use :#{dependency}", "could not find packages for dependency '#{dependency}'."
      end
    end
  end

  def write_template(source, target, binding_object = binding)
    template = @templates[source] ||= ERB.new(template(source), nil, '<>')
    puts "write #{target} from template #{source}"
    File.open(target, 'w') { |f| f.write template.result(binding_object) }
  end

  def template(file)
    File.read(File.expand_path("../../templates/#{file}.erb", __FILE__))
  end

  def exec(*args)
    puts *args
    Kernel::exec *args
  end

  def puts_with_indent(string)
    puts "#{'  ' * @indent}#{string}"
  end

  def with_indent
    @indent += 1
    yield
    @indent -= 1
  end
end
