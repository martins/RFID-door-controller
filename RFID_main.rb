require 'rubygems'
require 'serialport'
require 'sqlite3'
require 'daemons'


#params for serial port
port_str = "/dev/ttyUSB0"
baud_rate = 19200
data_bits = 8
stop_bits = 1
parity = SerialPort::NONE

@sp = SerialPort.new(port_str, baud_rate, data_bits, stop_bits, parity)

#Opens Data Base and selects all fields from card_id column
db = SQLite3::Database.new( File.join(File.dirname(__FILE__), "Cards.sqlite"))
rows = db.execute( "select card_id from card_list")
rows.flatten!

db=SQLite3::Database.new( File.join(File.dirname(__FILE__), "RFID_Report.sqlite"))

loop do
  sleep 2

  def get_response()
    @count = 0
    @response = []
    #Get First 4 byte from the device, this includes command and length information of data.
    begin
      cripted_binstring = @sp.read(4)
    rescue
      return false
    end
    binstring = cripted_binstring.to_s
    binstring.each_byte{|c_b|
      @response << c_b
    }
    #@response[2] represents length of data+checksum. This can not be greater than 20.
    return false if @response[2]>20
    #Get Remaining data
    begin
      cripted_binstring=@sp.read(@response[2])
    rescue
      return false
    end
    binstring = cripted_binstring.to_s
    binstring.each_byte{|c_b|
      @response << c_b
    }
    @count = @response[2]+4
    return true
  end


  def get_data()
    y = 0
    if(@count >= 4)
      #We wont use final byte that is Checksum
      @count -= 1
      i = 4
      while i < @count
        @response[y] = @response[i]
        i = i + 1
        y = y + 1
      end
    end
    @count = y
  end

  @sp.write("\xFF\x00\x01\x82\x83")
  continue = false
  valid_card = false
  if get_response()
    get_data()
    if (@response[0] == 0x4C)
      continue = true
    end
    #GET TAG SERIAL
    if continue == true
      tag_serial=[]
      valid_card = false
      if get_response()
        get_data()
        if @count > 1
          tag_type = @response[0]
          tag_serial[0] = @response[4]
          tag_serial[1] = @response[3]
          tag_serial[2] = @response[2]
          tag_serial[3] = @response[1]
          valid_card = true
        end
      end
    end
  end

  time = Time.now.strftime("%d.%m.%Y. %H:%M:%S")

  if continue==false
    #puts "Atbildes komanda: #{@response[0]}"
  end
  if valid_card
    serial = ""
    #puts "Tag type: #{tag_type.to_s(16)}"
    #print "Tag serial: "
    tag_serial.each{|t_s|
      serial << t_s.to_s(16)
      #print t_s.to_s(16), " "
    }
    #puts ""
    if rows.include?(serial)
      #puts "Serial is in db, opening doors!"
      #Command to switch on Output1
      @sp.write("\xFF\x00\x02\x92\x01\x95")
      if get_response()
        get_data()
        if @response[0] == 01
          #puts "Doors opened."
          sleep 5
          #Command to switch off both Outputs
          @sp.write("\xFF\x00\x02\x92\x00\x94")
          #puts "Doors closed."
          get_response()
        end
      end
      db.execute( "insert into Entries ('serial_nr','time') values ('#{serial}','#{time}')")
    else
      #puts "Serial is not in the db."
    end
    #puts serial  
  end
  #puts "End of session"
  #puts ""
end

@sp.close
