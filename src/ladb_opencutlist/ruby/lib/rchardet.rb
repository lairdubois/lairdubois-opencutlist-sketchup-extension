######################## BEGIN LICENSE BLOCK ########################
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301  USA
######################### END LICENSE BLOCK #########################

require_relative 'rchardet/version'
require_relative 'rchardet/charsetprober'
require_relative 'rchardet/mbcharsetprober'

require_relative 'rchardet/big5freq'
require_relative 'rchardet/big5prober'
require_relative 'rchardet/chardistribution'
require_relative 'rchardet/charsetgroupprober'

require_relative 'rchardet/codingstatemachine'
require_relative 'rchardet/constants'
require_relative 'rchardet/escprober'
require_relative 'rchardet/escsm'
require_relative 'rchardet/eucjpprober'
require_relative 'rchardet/euckrfreq'
require_relative 'rchardet/euckrprober'
require_relative 'rchardet/euctwfreq'
require_relative 'rchardet/euctwprober'
require_relative 'rchardet/gb18030freq'
require_relative 'rchardet/gb18030prober'
require_relative 'rchardet/hebrewprober'
require_relative 'rchardet/jisfreq'
require_relative 'rchardet/jpcntx'
require_relative 'rchardet/langbulgarianmodel'
require_relative 'rchardet/langcyrillicmodel'
require_relative 'rchardet/langgreekmodel'
require_relative 'rchardet/langhebrewmodel'
require_relative 'rchardet/langhungarianmodel'
require_relative 'rchardet/langthaimodel'
require_relative 'rchardet/latin1prober'

require_relative 'rchardet/mbcsgroupprober'
require_relative 'rchardet/mbcssm'
require_relative 'rchardet/sbcharsetprober'
require_relative 'rchardet/sbcsgroupprober'
require_relative 'rchardet/sjisprober'
require_relative 'rchardet/universaldetector'
require_relative 'rchardet/utf8prober'

module Ladb::OpenCutList
  module CharDet
    def CharDet.detect(aBuf)
      aBuf = aBuf.dup.force_encoding(Encoding::BINARY)

      u = UniversalDetector.new
      u.reset
      u.feed(aBuf)
      u.close
      u.result
    end
  end
end
