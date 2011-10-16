require 'rubygems'
require 'daemons'
require 'serialport'
require 'sqlite3'

name="RFID_output"

options = {
  :log_output => false,
  :backtrace => true,
  :app_name => name
}


Daemons.run(File.join(File.dirname(__FILE__), 'RFID_main.rb'), options)