class Dist::Configuration
  attr_reader :dependencies

  def initialize
    @vars = {}
    @dependencies = []
  end

  def set(name, value)
    @vars[name] = value
  end

  def use(service)
    @dependencies << service
  end

  def method_missing(name, *args)
    if args.empty? && value = @vars[name]
      return value
    end
    super
  end

end