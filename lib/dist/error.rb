module Dist::Error
  def error(error_string)
    puts "Error: #{error_string}"
    exit 1
  end

  def error_at(location, error_string)
    puts "Error at '#{location}': #{error_string}"
    exit 1
  end
end