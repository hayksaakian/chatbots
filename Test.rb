#!/usr/bin/ruby
require 'bundler/setup'
Bundler.require

include Appscript

app("TextEdit").activate
app("System Events").keystroke("Look Ma, keystrokes!")