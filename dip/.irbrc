# frozen_string_literal: true

require 'irb/ext/save-history'

IRB.conf[:SAVE_HISTORY] = 200
IRB.conf[:HISTORY_FILE] = '/usr/local/hist/.irb-history'
