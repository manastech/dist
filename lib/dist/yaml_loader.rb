class Dist::YamlLoader
  include Dist::Error

  def initialize(options = {})
    @local = options[:local]
    unless @local
      require "net/https"
      require "uri"
    end
  end

  def load(filename)
    @local ? load_from_local_file(filename) : load_from_url(filename)
  end

  def load_from_local_file(filename)
    YAML.load_file File.expand_path("../../#{filename}.yml", __FILE__)
  end

  def load_from_url(filename)
    uri = URI.parse("https://raw.github.com/manastech/dist/master/lib/#{filename}.yml")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    if response.code != '200'
      error "fetching '#{uri}' got status code #{response.code}. You can try running dist with --local if the problem persists."
    end
    YAML.load response.body
  rescue SocketError => ex
    error "couldn't fetch '#{uri}'. You can try running dist --local if you don't have internet access.\n(Exception is: #{ex.message})"
  end
end