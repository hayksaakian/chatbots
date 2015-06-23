#!/usr/bin/ruby
require 'bundler/setup'
Bundler.require

include Appscript

KEYCODE_MAP = {
	"w" => 13,
	"a" => 0,
	"s" => 1,
	"d" => 2,
	"q" => 12,
	"e" => 14,
	"z" => 6,
	"x" => 7
}


puts 'say something'

s = gets

puts "you said"
puts s
puts "ok?"

# The application may be identified by name, path, bundle ID, creator type, Unix process id
vba = app("VisualBoyAdvance")
vba.activate

sys = app("System Events")

# app("System Events").keystroke("Look Ma, keystrokes!")