# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

module OmfCommon
  PROTOCOL_VERSION = "6.0"

  def self.version_of(name)
    git_tag  = `git describe --tags 2> /dev/null`
    gem_v = Gem.loaded_specs[name].version.to_s rescue '0.0.0'
    git_tag.empty? ? gem_v : git_tag.gsub(/-/, '.')
  end

  VERSION = version_of('omf_common')
end
