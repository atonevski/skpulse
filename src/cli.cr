require "option_parser"
require "time"

module SKPulseCLI
  DTM_FMT = "%Y-%m-%dT%H:%M"

  # default options
  opts : Hash(String, String|Time) = {
    "type"  => "PM10",
    "sensor" => "any",
    "to" => Time.now,
    "from" => Time.now() - Time::Span.new(0, 24, 0, 0)
  }

  p = OptionParser.parse! do |parser|
    parser.banner = "Usage skpulse list|24|avg|..."

    parser.on "-t TYPE", "--type=TYPE", 
      "TYPE: pm10|pm25|noise|temp[erature]|humidity|any" do |t|
      unless /^(pm10|pm25|noise|temp(erature)?|humidity|any)$/i =~ t
        puts "Invalid TYPE: '#{ t }'"
        puts parser
        exit 1
      end
      opts["type"] = t.downcase
    end

    parser.on "-s SENSOR", "--sensor=SENSOR", "SENSOR: sensor_id | description" do |s|
      opts["sensor"] = s
    end

    parser.on "-f FROM", "--from=FROM", "FROM: yyyy-mm-ddTHH:MM" do |from|
      begin
        opts["from"] = Time.parse from, DTM_FMT, Time::Location.local
      rescue e
        puts "Invalid datetime format: #{ e.message }"
        puts
        puts parser
        exit 1
      end
    end

    parser.on "-e TO", "--to=TO", "TO: yyyy-mm-ddTHH:MM" do |to|
      begin
        opts["to"] = Time.parse to, DTM_FMT, Time::Location.local
      rescue e
        puts "Invalid datetime format: #{ e.message }"
        puts
        puts parser
        exit 1
      end
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
    when "24"
      skp_api.get_24h
      if opts["sensor"] == "any"
        skp_api.sensors.as_a.each do |s|
          skp_api.print_sensor s["sensorId"].as_s
        end
      else
        re = /^#{ opts["sensor"] }/i
        sarr = skp_api.sensors.as_a.select do |s|
          s["sensorId"].as_s =~ re || s["description"].as_s =~ re
        end
        sarr.each do |s|
          skp_api.print_sensor s["sensorId"].as_s
        end
      end
    when "avg"
      puts "From #{ opts["from"] }"
      skp_api.print_avg opts["from"].as(Time), opts["to"].as(Time)
    else # default command
      skp_api.get_24h
      skp_api.print_sensor skp_api.sensors[1]["sensorId"].as_s
    end
  end

  # def self.list_sensors(api : SKPulse::API)
  #   api.print_sensors
  # end
end
