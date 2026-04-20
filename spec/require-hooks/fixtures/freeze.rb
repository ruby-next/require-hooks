$events << [:before_file, File.basename(__FILE__)]
class Freezy
  class << self
    def weather
      "cold"
    end
  end
end
$events << [:after_file, File.basename(__FILE__)]
