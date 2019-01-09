require "./*"

require "http/client"
require "uri"
require "json"
require "base64"
require "colorize"

# TODO: Write documentation for `Skpulse`
module SKPulse
  VERSION = "0.1.0"

  class API
    USERNAME = "atonevski"
    PASSWORD = "pv1530kay" 
    CITY = "skopje"
    TM_FMT = "%Y-%m-%dT%H:%M:%S%:z"

    TYPES = {
      :pm10 => {
        :levels => {
          :good            =>   0...50,
          :moderate        =>  50...100,
          :sensitive       => 100...250,
          :unhealthy       => 250...350,
          :very_unhealthy  => 350...430,
          :hazardous       => 430...2000
        }
      },
      :pm25 => {
        :levels => {
          :good            =>   0...30,
          :moderate        =>  30...60,
          :sensitive       =>  60...90,
          :unhealthy       =>  90...120,
          :very_unhealthy  => 120...250,
          :hazardous       => 250...2000
        }
      },
      :noise => {
        :levels => {
          :good            =>   0...20, # silent/faint
          :moderate        =>  20...40, # normal
          :sensitive       =>  40...60, # noisy
          :unhealthy       =>  60...80, # loud
          :very_unhealthy  =>  80...120,# 
          :hazardous       => 120...190 # hazardous
        }
      }
    }


    getter sensors : JSON::Any
    getter measurements : JSON::Any

    def initialize(@username = USERNAME, @password = PASSWORD)
      @sensors = JSON.parse "[]"
      @measurements = JSON.parse "[]"
      @hostname = "#{ CITY }.pulse.eco"
      @enc64 = Base64.strict_encode @username + ":" + @password
    end

    def self.type_to_sym(t : String)
      case t
      when "pm10"
        :pm10
      when "pm25"
        :pm25
      when "humidity"
        :humidity
      when "noise"
        :noise
      else
        :any
      end
    end
    
    def self.type_level(type : Symbol, val : Int32)
      return :undefined unless [:pm10, :pm25, :noise].includes? type

      levels = TYPES[type][:levels]
                .as Hash(Symbol, Range(Int32, Int32))

      case
      when levels[:good].includes? val
        :good
      when levels[:moderate].includes? val
        :moderate
      when levels[:sensitive].includes? val
        :sensitive
      when levels[:unhealthy].includes? val
        :unhealthy
      when levels[:very_unhealthy].includes? val
        :very_unhealthy
      when levels[:hazardous].includes? val
        :hazardous
      else
        :undefined
      end
    end

    def self.level_color(level : Symbol)
      case level
      when :good
        :green
      when :moderate
        :yellow
      when :sensitive
        :yellow
      when :unhealthy
        :red
      when :very_unhealthy
        :red
      when :hazardous
        :magenta
      else
        :white
      end
    end
    # you should call immediately after .new
    def get_sensors
      HTTP::Client.new host: @hostname, port: 443, tls: true do |client|
        path = "/rest/sensor"
        headers = HTTP::Headers {
          "Accept-Charset" => "utf-8",
          "Accept" => "application/json",
          "Authorization" => "Basic #{ @enc64 }"
        }
        client.get path, headers: headers do |res|
          @sensors = JSON.parse res.body_io.gets_to_end
        end
      end
      @sensors
    end

    # get last 24h measurements from all sensors for all parameters
    def get_24h
      HTTP::Client.new host: @hostname, port: 443, tls: true do |client|
        path = "/rest/data24h"
        headers = HTTP::Headers {
          "Accept-Charset" => "utf-8",
          "Accept" => "application/json",
          "Authorization" => "Basic #{ @enc64 }"
        }
        client.get path, headers: headers do |res|
          @measurements = JSON.parse res.body_io.gets_to_end
        end
      end
    end

    # get rawdata 
    def get_raw_data(sensor_id : String, value_type : String, from : Time, to : Time)
      HTTP::Client.new host: @hostname, port: 443, tls: true do |client|
        path = "/rest/dataRaw?sensorId=#{ sensor_id }&" +
               "type=#{ value_type.downcase }&" +
               "from=#{ URI.escape from.to_s TM_FMT }&" +
               "to=#{ URI.escape to.to_s TM_FMT }"
        headers = HTTP::Headers {
          "Accept-Charset" => "utf-8",
          "Accept" => "application/json",
          "Authorization" => "Basic #{ @enc64 }"
        }
        begin
          client.get path, headers: headers do |res|
            @measurements = JSON.parse res.body_io.gets_to_end
          end
        rescue ex
          puts "Get RawData exception: #{ ex.message }"
        end
      end
    end

    # get rawdata 
    def get_raw_data_by_sensor(sensor_id : String, from : Time, to : Time)
      HTTP::Client.new host: @hostname, port: 443, tls: true do |client|
        path = "/rest/dataRaw?sensorId=#{ sensor_id }&" +
               "from=#{ URI.escape from.to_s TM_FMT }&" +
               "to=#{ URI.escape to.to_s TM_FMT }"
        headers = HTTP::Headers {
          "Accept-Charset" => "utf-8",
          "Accept" => "application/json",
          "Authorization" => "Basic #{ @enc64 }"
        }
        begin
          client.get path, headers: headers do |res|
            @measurements = JSON.parse res.body_io.gets_to_end
          end
        rescue ex
          puts "Get RawData exception: #{ ex.message }"
        end
      end
    end

    # get rawdata 
    def get_raw_data_by_type(value_type : String, from : Time, to : Time)
      HTTP::Client.new host: @hostname, port: 443, tls: true do |client|
        path = "/rest/dataRaw?" +
               "type=#{ value_type.downcase }&" +
               "from=#{ URI.escape from.to_s TM_FMT }&" +
               "to=#{ URI.escape to.to_s TM_FMT }"
        headers = HTTP::Headers {
          "Accept-Charset" => "utf-8",
          "Accept" => "application/json",
          "Authorization" => "Basic #{ @enc64 }"
        }
        begin
          client.get path, headers: headers do |res|
            @measurements = JSON.parse res.body_io.gets_to_end
          end
        rescue ex
          puts "Get RawData exception: #{ ex.message }"
        end
      end
    end

    def print_sensor(sensor_id : String)
      sensor = @sensors.as_a.select {|s| s["sensorId"] == sensor_id}[0]

      arr = @measurements.as_a.select {|x| x["sensorId"] == sensor_id}
      tms = arr.map {|x| x["stamp"].as_s}.uniq
      types = arr.map {|x| x["type"].as_s}.uniq

      type_index = {} of String => Int32 # Hash(String, Int32)
      types.each_with_index do |t, i|
        type_index[t] = i
      end

      h = {} of String  => Array(String|Nil)
      arr.each do |m|
        unless h.has_key? m["stamp"]
          h[m["stamp"].as_s] = Array(String|Nil).new(types.size, nil)
        end
        h[m["stamp"].as_s][type_index[m["type"]]] = m["value"].as_s
      end

      Colorize.on_tty_only!
      
      puts
      puts "Sensor: #{ sensor["description"] }"
      puts "Id: #{ sensor["sensorId"] }"
      puts "Status: #{ sensor["status"] }"
      puts 
      printf "%-19s", "time"
      types.each {|t| printf " %11.11s", t}
      puts

      ln = "─"*60
      printf "%-19.19s", ln
      types.each {|t| printf " %11.11s", ln}
      puts

      tms.each do |t|
        printf "%-19.19s", t
        h[t].each_with_index do |m, i|
          if m.nil? || !["pm10", "pm25"].includes?(types[i])
            printf " %11.11s", (m.nil? ? "" : m)
          else
            level = API.type_level API.type_to_sym(types[i]), m.to_i32
            color = API.level_color level
            print (sprintf " %11.11s", m).colorize(color)
          end
        end
        puts
      end
    end

    def print_sensors
      ln = "─"*60
      printf "%-15.15s %30.30s %10.10s %25.25s\n", "descriptions", "id",
        "status", "position"
      printf "%-15.15s %30.30s %10.10s %25.25s\n", ln, ln, ln, ln
      @sensors.as_a.each do |s|
        pos = s["position"].as_s.split ","
        printf "%-15.15s %30.30s %10.10s %12.12s, %-12.12s\n", s["description"], s["sensorId"],
          s["status"], pos[0], pos[1]
      end
      puts
    end
  end
  
  # # TODO:
  # - levels: borrow from air.cr
  # - CLI interface
  #    [flags] commands...
  #    1. 24h: sorted by sensor
  #    2. sensor: one sensor all parameters...
  # 
  # # DONE:
  # - finish all get_raw_data variants

end

# PM10 aq
# 
# [
#   {'from':0.0,'to':15.0,'legendPoint':0.0,'legendColor':'green',
#   'markerColor':'green','shortGrade':'Good air quality.','grade':'Good air quality. Air quality is considered satisfactory, and air pollution poses little or no risk','suggestion':'No preventive measures needed, enjoy the fresh air.'},
#   {'from':16.0,'to':30.0,'legendPoint':23.0,'legendColor':'darkgreen','markerColor':'darkgreen','shortGrade':'Moderate air quality.','grade':'Moderate air quality. Air quality is acceptable; however, for some pollutants there may be a moderate health concern for a very small number of people.','suggestion':'Consider limiting your outside exposure if you\'re sensitive to bad air.'},
#   {'from':31.0,'to':55.0,'legendPoint':45.0,'legendColor':'orange','markerColor':'orange','shortGrade':'Bad air quality.','grade':'Bad air quality. Unhealthy for Sensitive Groups, people with lung disease, older adults and children.','suggestion':'Limit your outside exposure if you\'re sensitive to bad air.'},
#   {'from':56.0,'to':110.0,'legendPoint':83.0,'legendColor':'red','markerColor':'red','shortGrade':'Very bad air quality.','grade':'Very bad air quality. Everyone may begin to experience some adverse health effects, and members of the sensitive groups may experience more serious effects.','suggestion':'Stay indoors if you\'re sensitive to bad air. Everyone should limit outside exposure'},
#   {'from':111.0,'to':1000.0,'legendPoint':110.0,'legendColor':'darkred','markerColor':'darkred','shortGrade':'Hazardous air quality!','grade':'Hazardous air quality! This would trigger a health warnings of emergency conditions. The entire population is more likely to be affected!','suggestion':'Stay indoors as much as possible.'}]


# PM25
#[{'from':0.0,'to':20.0,'legendPoint':0.0,'legendColor':'green','markerColor':'green','shortGrade':'Overall silence.','grade':'Overall silence. Human hearing can barely register noticeable noise.','suggestion':'Enjoy the peace and quiet.'},{'from':21.0,'to':40.0,'legendPoint':30.0,'legendColor':'darkgreen','markerColor':'darkgreen','shortGrade':'Generally quiet.','grade':'Generally quiet. Noise levels are noticeable but cause no discomfort.','suggestion':'No precautions necessary, noise levels are low.'},{'from':41.0,'to':60.0,'legendPoint':50.0,'legendColor':'orange','markerColor':'orange','shortGrade':'Moderately calm, about the level of a conversation.','grade':'Moderately calm, about the level of a conversation. Shouldn\'t cause discomfort','suggestion':'Try to limit exposure if you\'re very sensitive to noise.'},{'from':61.0,'to':85.0,'legendPoint':68.0,'legendColor':'red','markerColor':'red','shortGrade':'Noisy urban daytime.','grade':'Noisy urban daytime. Standard city noise pollution, can cause discomfort.','suggestion':'Try to avoid prolonged exposure as it can be irritating, no medical precautions necessary.'},{'from':86.0,'to':140.0,'legendPoint':88.0,'legendColor':'darkred','markerColor':'darkred','shortGrade':'Generally loud. Will likely cause discomfort.','grade':'Generally loud. Will likely cause discomfort. Temporary hearing loss possible after prolonged exposure.','suggestion':'Try to stay indoors. If you\'re experiencing any ear ringing, rest your ears for 16 hours to recover.'},{'from':141.0,'to':255.0,'legendPoint':151.0,'legendColor':'purple','markerColor':'purple','shortGrade':'Uncomfortably loud.','grade':'Uncomfortably loud. Temporary hearing loss may occur after prolonged exposure with possible ear pain and dizziness.','suggestion':'Stay indoors as much as possible. Consider wearing ear protection if you\'re going outside for longer periods.'}]
