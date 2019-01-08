require "option_parser"

module SKPulseCLI
  opts = {
    "type"  => "PM10",
    "sensor" => "any"
  }

  p = OptionParser.parse! do |parser|
    parser.banner = "Usage skpulse list|24|..."

    parser.on "-t TYPE", "--type=TYPE", 
      "TYPE: pm10|pm25|noise|temp[erature]|humidity|any" do |t|
      unless /^(pm10|pm25|noise|temp(erature)?|humidity|any)$/i =~ t
        puts "Invalid TYPE: '#{ t }'"
        puts parser
        exit 1
      end
      opts["type"] = t.downcase
    end

    parser.on "-h", "--help", "Show this help" do
      puts parser
      exit 1
    end
  end

  # show help if no args
  puts p if ARGV.size == 0
  skp_api = SKPulse::API.new
  skp_api.get_sensors

  ARGV.each do |cmd|
    case cmd
    when "list"
      # list_sensors skp_api
      skp_api.print_sensors
    end
  end

  # def self.list_sensors(api : SKPulse::API)
  #   api.print_sensors
  # end
end
