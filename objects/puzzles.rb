# Copyright (c) 2016-2017 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'nokogiri'
require_relative 'safe_tickets'

#
# Puzzles in XML/S3
#
class Puzzles
  def initialize(repo, storage)
    @repo = repo
    @storage = storage
  end

  def deploy(tickets)
    expose(
      save(
        group(
          join(@storage.load, @repo.xml)
        )
      ),
      SafeTickets.new(tickets)
    )
  end

  private

  def save(xml)
    @storage.save(xml)
    xml
  end

  def join(before, snapshot)
    after = Nokogiri::XML(before.to_s)
    target = after.xpath('/puzzles')[0]
    snapshot.xpath('//puzzle').each do |p|
      p.name = 'extra'
      target.add_child(p)
    end
    after
  end

  def group(xml)
    Nokogiri::XSLT(File.read('assets/xsl/group.xsl')).transform(
      Nokogiri::XSLT(File.read('assets/xsl/join.xsl')).transform(xml)
    )
  end

  def expose(xml, tickets)
    return unless tickets.safe
    xml.xpath('//puzzle[@alive="false" and issue and issue!="unknown"]')
      .each { |p| tickets.close(p) }
    xml.xpath('//puzzle[@alive="true" and (not(issue) or issue="unknown")]')
      .map { |p| { issue: tickets.submit(p), id: p.xpath('id')[0].text } }
      .reject { |p| p[:issue].nil? }
      .each do |p|
        node = xml.xpath("//puzzle[id='#{p[:id]}']")[0]
        node.search('issue').remove
        node.add_child(
          "<issue href='#{p[:issue][:href]}'>#{p[:issue][:number]}</issue>"
        )
        save(xml)
      end
  end
end
