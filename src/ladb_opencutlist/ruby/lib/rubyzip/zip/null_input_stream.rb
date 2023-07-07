# frozen_string_literal: true

module Ladb::OpenCutList::Zip
  module NullInputStream # :nodoc:all
    include Ladb::OpenCutList::Zip::NullDecompressor
    include Ladb::OpenCutList::Zip::IOExtras::AbstractInputStream
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
