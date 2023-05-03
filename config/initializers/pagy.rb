# frozen_string_literal: true

require 'pagy'
require 'pagy/extras/overflow'

Pagy::DEFAULT[:overflow] = :last_page
