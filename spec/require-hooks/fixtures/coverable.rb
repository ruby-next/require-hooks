class Coverable
  def self.call
    "cover up"
  end
end

if Coverable.call.include?("up")
  puts "UP!"
else
  puts "DOWN!"
end
