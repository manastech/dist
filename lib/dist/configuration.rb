class Dist::Configuration
  include Dist::Error

  attr_reader :dependencies
  attr_reader :sections
  attr_reader :after_install_commands
  attr_reader :before_build_commands

  def initialize
    @vars = {}
    @dependencies = []
    @sections = []
    @after_install_commands = []
    @before_build_commands = []

    config_contents = File.read("config/dist.rb") rescue error("config/dist.rb file not found. Please run `dist init`.")
    instance_eval config_contents
  end

  def set(name, value)
    @vars[name] = value
  end

  def get(name)
    if @vars.has_key?(name)
      @vars[name]
    else
      error "missing setting '#{name}'"
    end
  end

  def use(service)
    @dependencies << service
  end

  def config(section, &block)
    config_section = Section.new(section)
    config_section.instance_eval &block
    @sections << config_section
  end

  def after_install(command)
    @after_install_commands << command
  end

  def before_build(command)
    @before_build_commands << command
  end

  def method_missing(name, *args)
    if args.empty? && value = @vars[name]
      return value
    end
    super
  end

  class Section
    include Dist::Error

    attr_reader :name
    attr_reader :properties

    def initialize(name)
      @name = name
      @properties = []

      @filename = "config/#{name}.yml"
      unless File.exists?(@filename)
        error_at "config :#{name}", "the file '#{@filename}' doesn't exist."
      end

      @yaml = YAML.load_file @filename
      @yaml = @yaml['production'] || @yaml
    end

    def string(name, options = {})
      add_property name, :string, options
    end

    def add_property(name, type, options = {})
      unless @yaml.has_key?(name.to_s)
        error_at "#{type}: :#{name}", "the property '#{name}' inside the file '#{@filename} doesn't exist."
      end

      @properties << Property.new(self, name, type, options)
    end

    def to_s
      name.to_s
    end
  end

  class Property
    attr_reader :name
    attr_reader :type

    def initialize(section, name, type, options = {})
      @section = section
      @name = name
      @type = type
      @options = options
    end

    def full_name
      "#{@section.name}/#{name}"
    end

    def default_value
      @options[:default]
    end

    def prompt
      @options[:prompt] || "#{@section.name} #{name}"
    end
  end
end
