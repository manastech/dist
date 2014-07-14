class Dist::PackageComputer
  def initialize(config, options = {})
    @config = config
    @yaml_loader = Dist::YamlLoader.new options
  end

  def packages
    compute_packages
  end

  private

  def compute_packages
    puts "Computing packages..."
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
    @config.dependencies.each do |dependency|
      if @dependencies.add?(dependency)
        add_packages_from_dependency(dependency)
      end
    end
  end

  def add_dependencies_from_bundle
    use_git = false
    Bundler.load.specs.each do |spec|
      if spec.respond_to?(:source) && spec.source.class == Bundler::Source::Git
        use_git = true
      end
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
    if use_git
      add_packages_from_dependency('git')
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

  def puts_with_indent(string)
    puts "#{'  ' * @indent}#{string}"
  end

  def with_indent
    @indent += 1
    yield
    @indent -= 1
  end
end
